import Foundation

/// A data-loss-prevention scanner that redacts known secret values from text —
/// e.g. an AI agent's stdout — before it can leak into a model's context or a
/// log. Backs `lokalite guard`, reaching parity with NoxKey's `guard` (ROADMAP,
/// P0).
///
/// Pure and synchronous so it can be unit-tested without a vault.
public struct SecretLeakScanner {
    /// A secret value that appeared in the scanned text.
    public struct Finding: Equatable {
        /// Names of the secrets sharing the leaked value (usually one).
        public let secretNames: [String]
        /// How many times the value appeared.
        public let occurrences: Int
    }

    public struct Result: Equatable {
        /// The input with every recognised secret value replaced by a marker.
        public let redactedText: String
        public let findings: [Finding]
        public var hasLeaks: Bool { !findings.isEmpty }
    }

    /// Values shorter than this are ignored to avoid false positives from
    /// trivial values like "1", "true", or "dev".
    public static let minimumValueLength = 6

    // Unique values, longest first, each with the secret names that carry it.
    private let entries: [(value: String, names: [String])]

    public init(
        secrets: [(name: String, value: String)],
        minimumValueLength: Int = SecretLeakScanner.minimumValueLength
    ) {
        var namesByValue: [String: [String]] = [:]
        var order: [String] = []
        for secret in secrets {
            guard secret.value.count >= minimumValueLength else { continue }
            if namesByValue[secret.value] == nil { order.append(secret.value) }
            if !(namesByValue[secret.value]?.contains(secret.name) ?? false) {
                namesByValue[secret.value, default: []].append(secret.name)
            }
        }
        // Longest first so an overlapping shorter value can't pre-empt the
        // longer, more specific match.
        self.entries = order
            .sorted { $0.count > $1.count }
            .map { (value: $0, names: namesByValue[$0] ?? []) }
    }

    /// Returns `text` with every recognised secret value replaced by a
    /// `[redacted:NAME]` marker, plus one finding per leaked value.
    public func scan(_ text: String) -> Result {
        var redacted = text
        var findings: [Finding] = []
        for entry in entries {
            let occurrences = redacted.components(separatedBy: entry.value).count - 1
            guard occurrences > 0 else { continue }
            let marker = "[redacted:\(entry.names.joined(separator: "|"))]"
            redacted = redacted.replacingOccurrences(of: entry.value, with: marker)
            findings.append(Finding(secretNames: entry.names, occurrences: occurrences))
        }
        return Result(redactedText: redacted, findings: findings)
    }
}
