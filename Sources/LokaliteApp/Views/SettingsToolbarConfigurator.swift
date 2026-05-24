import AppKit
import SwiftUI
import LokaliteCore

struct SettingsToolbarConfigurator: NSViewRepresentable {
    @ObservedObject var vault: VaultViewModel
    @Binding var searchText: String

    let onSettings: () -> Void
    let onAddSecret: () -> Void
    let onNewEnvironment: () -> Void
    let onRenameEnvironment: (VaultEnvironment) -> Void
    let onDeleteEnvironment: (VaultEnvironment) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            vault: vault,
            searchText: $searchText,
            onSettings: onSettings,
            onAddSecret: onAddSecret,
            onNewEnvironment: onNewEnvironment,
            onRenameEnvironment: onRenameEnvironment,
            onDeleteEnvironment: onDeleteEnvironment
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(vault: vault, searchText: searchText)
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
        private var vault: VaultViewModel
        private var searchText: Binding<String>
        private let onSettings: () -> Void
        private let onAddSecret: () -> Void
        private let onNewEnvironment: () -> Void
        private let onRenameEnvironment: (VaultEnvironment) -> Void
        private let onDeleteEnvironment: (VaultEnvironment) -> Void

        private weak var window: NSWindow?
        private weak var addSecretToolbarItem: NSToolbarItem?
        private weak var environmentPopUp: NSPopUpButton?
        private weak var searchToolbarItem: NSToolbarItem?
        private weak var searchField: NSSearchField?
        private var isSearchExpanded = false

        init(
            vault: VaultViewModel,
            searchText: Binding<String>,
            onSettings: @escaping () -> Void,
            onAddSecret: @escaping () -> Void,
            onNewEnvironment: @escaping () -> Void,
            onRenameEnvironment: @escaping (VaultEnvironment) -> Void,
            onDeleteEnvironment: @escaping (VaultEnvironment) -> Void
        ) {
            self.vault = vault
            self.searchText = searchText
            self.onSettings = onSettings
            self.onAddSecret = onAddSecret
            self.onNewEnvironment = onNewEnvironment
            self.onRenameEnvironment = onRenameEnvironment
            self.onDeleteEnvironment = onDeleteEnvironment
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            self.window = window

            let toolbar = NSToolbar(identifier: .settingsToolbar)
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            toolbar.showsBaselineSeparator = true

            window.toolbar = toolbar
            window.toolbarStyle = .unified
        }

        func update(vault: VaultViewModel, searchText: String) {
            self.vault = vault
            if self.searchText.wrappedValue != searchText {
                self.searchText.wrappedValue = searchText
            }
            refreshEnvironmentMenu()
            refreshSearchField()
            addSecretToolbarItem?.isEnabled = vault.selectedProject != nil
            window?.toolbar?.validateVisibleItems()
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.environmentSelector, .actionGroup, .flexibleSpace, .searchField]
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.environmentSelector, .actionGroup, .flexibleSpace, .searchField]
        }

        func toolbar(
            _ toolbar: NSToolbar,
            itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar flag: Bool
        ) -> NSToolbarItem? {
            switch itemIdentifier {
            case .actionGroup:
                return makeActionGroup()
            case .environmentSelector:
                return makeEnvironmentSelector()
            case .searchField:
                return makeSearchItem()
            default:
                return nil
            }
        }

        private func makeActionGroup() -> NSToolbarItem {
            let settings = NSToolbarItem(itemIdentifier: .settingsAction)
            settings.label = "Settings"
            settings.paletteLabel = "Settings"
            settings.toolTip = "Settings"
            settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            settings.target = self
            settings.action = #selector(showSettings)

            let addSecretItem = NSToolbarItem(itemIdentifier: .addSecretAction)
            addSecretItem.label = "New Secret"
            addSecretItem.paletteLabel = "New Secret"
            addSecretItem.toolTip = "New secret"
            addSecretItem.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New secret")
            addSecretItem.target = self
            addSecretItem.action = #selector(addSecret)
            addSecretItem.isEnabled = vault.selectedProject != nil
            addSecretToolbarItem = addSecretItem

            let group = NSToolbarItemGroup(itemIdentifier: .actionGroup)
            group.label = "Actions"
            group.paletteLabel = "Actions"
            group.subitems = [settings, addSecretItem]
            return group
        }

        private func makeEnvironmentSelector() -> NSToolbarItem {
            let item = NSToolbarItem(itemIdentifier: .environmentSelector)
            item.label = "Environment"
            item.paletteLabel = "Environment"
            item.toolTip = "Environment"

            let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 160, height: 32), pullsDown: true)
            popUp.bezelStyle = .rounded
            popUp.controlSize = .large
            popUp.font = .systemFont(ofSize: 13, weight: .medium)
            popUp.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                popUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
                popUp.widthAnchor.constraint(lessThanOrEqualToConstant: 190),
                popUp.heightAnchor.constraint(equalToConstant: 32)
            ])

            item.view = popUp
            environmentPopUp = popUp
            refreshEnvironmentMenu()
            return item
        }

        private func makeSearchItem() -> NSToolbarItem {
            let item = NSToolbarItem(itemIdentifier: .searchField)
            item.label = "Search"
            item.paletteLabel = "Search"
            item.toolTip = "Search"
            searchToolbarItem = item
            configureCollapsedSearchItem()
            return item
        }

        private func refreshEnvironmentMenu() {
            guard let popUp = environmentPopUp else { return }
            let selectedTitle = vault.selectedEnvironment?.name ?? "Default"

            let menu = NSMenu()
            let titleItem = NSMenuItem(title: selectedTitle, action: nil, keyEquivalent: "")
            titleItem.attributedTitle = NSAttributedString(
                string: selectedTitle,
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium)
                ]
            )
            menu.addItem(titleItem)
            menu.addItem(.separator())

            let defaultItem = menuItem(title: "Default", action: .select(nil))
            defaultItem.state = vault.selectedEnvironment == nil ? .on : .off
            menu.addItem(defaultItem)

            for environment in vault.environments {
                let environmentItem = NSMenuItem(title: environment.name, action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                let selectItem = menuItem(title: "Select", action: .select(environment))
                selectItem.state = vault.selectedEnvironment?.id == environment.id ? .on : .off
                submenu.addItem(selectItem)
                submenu.addItem(.separator())
                submenu.addItem(menuItem(title: "Rename...", action: .rename(environment)))
                submenu.addItem(menuItem(title: "Delete", action: .delete(environment)))

                environmentItem.submenu = submenu
                menu.addItem(environmentItem)
            }

            if vault.selectedProject != nil {
                menu.addItem(.separator())
                menu.addItem(menuItem(title: "New Environment...", action: .newEnvironment))
            }

            popUp.menu = menu
            popUp.selectItem(at: 0)
            popUp.isEnabled = vault.selectedProject != nil
        }

        private func refreshSearchField() {
            guard let searchField, searchField.stringValue != searchText.wrappedValue else { return }
            searchField.stringValue = searchText.wrappedValue
            updateSearchPresentation()
        }

        private func updateSearchPresentation() {
            if searchText.wrappedValue.isEmpty && !isSearchExpanded {
                configureCollapsedSearchItem()
            } else {
                configureExpandedSearchItem()
            }
        }

        private func configureCollapsedSearchItem() {
            guard let searchToolbarItem else { return }
            let button = NSButton(
                image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search") ?? NSImage(),
                target: self,
                action: #selector(expandSearch)
            )
            button.bezelStyle = .texturedRounded
            button.controlSize = .large
            button.imagePosition = .imageOnly
            button.toolTip = "Search"
            searchToolbarItem.view = button
            searchField = nil
        }

        private func configureExpandedSearchItem() {
            guard let searchToolbarItem else { return }
            let field = NSSearchField(frame: NSRect(x: 0, y: 0, width: 240, height: 32))
            field.placeholderString = "Filter secrets..."
            field.controlSize = .large
            field.delegate = self
            field.target = self
            field.action = #selector(searchFieldAction(_:))
            field.stringValue = searchText.wrappedValue
            field.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                field.widthAnchor.constraint(equalToConstant: 240),
                field.heightAnchor.constraint(equalToConstant: 32)
            ])
            searchToolbarItem.view = field
            searchField = field
            window?.makeFirstResponder(field)
        }

        private func menuItem(title: String, action: EnvironmentMenuAction) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(handleEnvironmentMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action
            return item
        }

        @objc private func showSettings() {
            onSettings()
        }

        @objc private func addSecret() {
            guard vault.selectedProject != nil else { return }
            onAddSecret()
        }

        @objc private func handleEnvironmentMenuAction(_ sender: NSMenuItem) {
            guard let action = sender.representedObject as? EnvironmentMenuAction else { return }
            handle(action)
        }

        @objc private func expandSearch() {
            isSearchExpanded = true
            configureExpandedSearchItem()
        }

        @objc private func searchFieldAction(_ sender: NSSearchField) {
            searchText.wrappedValue = sender.stringValue
            collapseSearchIfEmpty()
        }

        private func handle(_ action: EnvironmentMenuAction) {
            switch action {
            case .select(let environment):
                vault.selectEnvironment(environment)
            case .newEnvironment:
                onNewEnvironment()
            case .rename(let environment):
                onRenameEnvironment(environment)
            case .delete(let environment):
                onDeleteEnvironment(environment)
            }
            refreshEnvironmentMenu()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            searchText.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            collapseSearchIfEmpty()
        }

        private func collapseSearchIfEmpty() {
            guard searchText.wrappedValue.isEmpty else { return }
            isSearchExpanded = false
            configureCollapsedSearchItem()
        }
    }
}

private enum EnvironmentMenuAction {
    case select(VaultEnvironment?)
    case newEnvironment
    case rename(VaultEnvironment)
    case delete(VaultEnvironment)
}

private extension NSToolbar.Identifier {
    static let settingsToolbar = NSToolbar.Identifier("com.lokalite.settings.toolbar")
}

private extension NSToolbarItem.Identifier {
    static let actionGroup = NSToolbarItem.Identifier("com.lokalite.settings.toolbar.actions")
    static let settingsAction = NSToolbarItem.Identifier("com.lokalite.settings.toolbar.settings")
    static let addSecretAction = NSToolbarItem.Identifier("com.lokalite.settings.toolbar.addSecret")
    static let environmentSelector = NSToolbarItem.Identifier("com.lokalite.settings.toolbar.environment")
    static let searchField = NSToolbarItem.Identifier("com.lokalite.settings.toolbar.search")
}
