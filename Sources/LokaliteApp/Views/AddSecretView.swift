import SwiftUI

struct AddSecretView: View {
    @EnvironmentObject private var vault: VaultViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var value = ""
    @State private var description = ""
    @State private var revealed = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !value.isEmpty
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
                    TextField("Description", text: $description)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Secret") {
                    vault.add(
                        name: name.trimmingCharacters(in: .whitespaces),
                        value: value,
                        description: description.isEmpty ? nil : description
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 440, height: 300)
    }
}
