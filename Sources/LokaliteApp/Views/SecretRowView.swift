import SwiftUI
import LokaliteCore

struct SecretRowView: View {
    let secret: Secret
    @EnvironmentObject private var vault: VaultViewModel
    @State private var copied = false
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                if revealed {
                    Text(secret.value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    Text(String(repeating: "•", count: min(secret.value.count, 16)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !secret.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(secret.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            Spacer()

            if copied {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { copySecret() }
        .contextMenu {
            Button("Copy") { copySecret() }
            Button(revealed ? "Hide" : "Reveal") {
                withAnimation(.easeInOut(duration: 0.15)) { revealed.toggle() }
            }
            Divider()
            Button("Delete", role: .destructive) { vault.delete(secret) }
        }
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
