public enum EnvFileFormat {
    public static func line(name: String, value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(name)=\"\(escaped)\""
    }

    /// Parse the contents of a `.env` file into ordered key/value pairs.
    /// Skips blank lines and `#` comments, strips an optional `export ` prefix,
    /// unwraps single/double quotes, and drops trailing ` #` comments on bare values.
    public static func parse(_ content: String) -> [(name: String, value: String)] {
        var result: [(name: String, value: String)] = []
        for rawLine in content.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") {
                line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
            guard let eqIdx = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            var value = String(line[line.index(after: eqIdx)...])
            if (value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2) ||
               (value.hasPrefix("'")  && value.hasSuffix("'")  && value.count >= 2) {
                value = String(value.dropFirst().dropLast())
            } else if let commentRange = value.range(of: " #") {
                value = String(value[value.startIndex..<commentRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
            result.append((name: key, value: value))
        }
        return result
    }
}
