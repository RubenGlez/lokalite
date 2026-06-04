import Foundation

public enum VaultConfiguration {
    #if DEBUG
    public static let isDevelopmentBuild = true
    public static let keychainService = "com.lokalite.vault.dev"
    private static let applicationSupportSubdirectory = "Lokalite/dev"
    #else
    public static let isDevelopmentBuild = false
    public static let keychainService = "com.lokalite.vault"
    private static let applicationSupportSubdirectory = "Lokalite"
    #endif

    public static var vaultFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("vault.db")
    }

    static var applicationSupportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(applicationSupportSubdirectory)
    }
}
