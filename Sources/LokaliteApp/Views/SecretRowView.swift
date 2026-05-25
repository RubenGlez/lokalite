import SwiftUI
import LokaliteCore

struct SecretRowView: View {
    let secret: Secret
    @EnvironmentObject private var vault: VaultViewModel
    @State private var copied = false

    var body: some View {
        Button {
            copySecret()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.14))
                    let icon = secret.category.defaultIcon
                    if !icon.isEmpty {
                        Text(icon)
                            .font(.system(size: 13))
                    } else {
                        Image(systemName: secret.category.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 22, height: 22)

                Text(secret.name)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)

                Spacer()

                if copied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contextMenu {
            Button("Copy") { copySecret() }
            Divider()
            Button("Delete", role: .destructive) { vault.delete(secret) }
        }
        .accessibilityLabel("Copy \(secret.name)")
        .animation(.easeInOut(duration: 0.15), value: copied)
    }

    private func copySecret() {
        vault.copyToClipboard(secret)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}
