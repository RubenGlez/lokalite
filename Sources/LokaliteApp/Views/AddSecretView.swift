import SwiftUI
import LokaliteCore

struct AddSecretView: View {
    @Environment(VaultViewModel.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var value = ""
    @State private var description = ""
    @State private var category: SecretCategory = .other
    @State private var revealed = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !value.isEmpty
    }

    private var detectedCategory: SecretCategory {
        SecretCategory.infer(name: name, value: value, description: description)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()

                    HStack {
                        if revealed {
                            TextField("Value", text: $value)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Value", text: $value)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button {
                            revealed.toggle()
                        } label: {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(revealed ? "Hide secret value" : "Reveal secret value")
                    }
                }

                Section("Optional") {
                    Picker("Category", selection: $category) {
                        ForEach(SecretCategory.allCases, id: \.self) { category in
                            Label(category.label, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }

                    TextField("Description", text: $description)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Secret")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        vault.add(
                            name: name.trimmingCharacters(in: .whitespaces),
                            value: value,
                            description: description.isEmpty ? nil : description,
                            category: category
                        )
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 440, height: 320)
        .onChange(of: name) { category = detectedCategory }
        .onChange(of: value) { category = detectedCategory }
        .onChange(of: description) { category = detectedCategory }
    }
}
