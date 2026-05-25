import Foundation

public enum SecretCategory: String, Codable, CaseIterable, Hashable {
    case token
    case apiKey = "api_key"
    case password
    case secret
    case certificate
    case database
    case webhook
    case other

    public var label: String {
        switch self {
        case .token: return "Token"
        case .apiKey: return "API Key"
        case .password: return "Password"
        case .secret: return "Secret"
        case .certificate: return "Certificate"
        case .database: return "Database"
        case .webhook: return "Webhook"
        case .other: return "Other"
        }
    }

    public static func infer(name: String, value: String, description: String? = nil) -> SecretCategory {
        let lowerValue = value.lowercased()
        let haystack = [
            name,
            description ?? "",
            normalizedValueHint(value)
        ]
        .joined(separator: " ")
        .lowercased()

        if haystack.contains("certificate") ||
            haystack.contains("cert") ||
            value.contains("-----BEGIN CERTIFICATE-----") ||
            value.contains("-----BEGIN PRIVATE KEY-----") {
            return .certificate
        }

        if haystack.contains("password") ||
            haystack.contains("passwd") ||
            haystack.contains("pwd") {
            return .password
        }

        if haystack.contains("database") ||
            haystack.contains("db_") ||
            haystack.contains("postgres") ||
            haystack.contains("mysql") ||
            haystack.contains("mongodb") ||
            haystack.contains("redis") {
            return .database
        }

        if haystack.contains("webhook") ||
            haystack.contains("callback") ||
            haystack.contains("slack_hook") {
            return .webhook
        }

        if haystack.contains("api_key") ||
            haystack.contains("apikey") ||
            haystack.contains("secret_key") ||
            haystack.contains("public_key") ||
            haystack.contains("publishable_key") ||
            haystack.contains("client_key") ||
            haystack.contains("key") {
            return .apiKey
        }

        if haystack.contains("secret") {
            return .secret
        }

        if haystack.contains("token") ||
            haystack.contains("bearer") ||
            haystack.contains("access_token") ||
            haystack.contains("refresh_token") ||
            lowerValue.hasPrefix("ghp_") ||
            lowerValue.hasPrefix("github_pat_") ||
            lowerValue.hasPrefix("xox") ||
            lowerValue.hasPrefix("sk-") {
            return .token
        }

        return .other
    }

    private static func normalizedValueHint(_ value: String) -> String {
        if value.hasPrefix("postgres://") || value.hasPrefix("postgresql://") { return "postgres" }
        if value.hasPrefix("mysql://") { return "mysql" }
        if value.hasPrefix("mongodb://") || value.hasPrefix("mongodb+srv://") { return "mongodb" }
        if value.hasPrefix("redis://") { return "redis" }
        if value.hasPrefix("https://hooks.") { return "webhook" }
        return value.prefix(32).description
    }
}
