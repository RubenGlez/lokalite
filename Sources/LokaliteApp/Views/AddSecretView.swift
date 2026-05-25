import SwiftUI
import LokaliteCore

struct AddSecretView: View {
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    var onClose: () -> Void = {}

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
        VStack(spacing: 0) {
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

            Divider()

            HStack {
                Button("Cancel") { close() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Secret") {
                    vault.add(
                        name: name.trimmingCharacters(in: .whitespaces),
                        value: value,
                        description: description.isEmpty ? nil : description,
                        category: category
                    )
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 440, height: 320)
        .onChange(of: name) { category = detectedCategory }
        .onChange(of: value) { category = detectedCategory }
        .onChange(of: description) { category = detectedCategory }
    }

    private func close() {
        onClose()
        dismiss()
    }
}
