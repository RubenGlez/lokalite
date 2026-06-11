public enum EnvFileFormat {
    public static func line(name: String, value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(name)=\"\(escaped)\""
    }
}
