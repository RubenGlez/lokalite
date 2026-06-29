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

    /// Unix socket the menu-bar app (daemon) listens on and the CLI/MCP client
    /// connects to (ADR 0014). Co-located with the vault so dev and release
    /// builds use separate sockets.
    public static var daemonSocketURL: URL {
        applicationSupportDirectory.appendingPathComponent("daemon.sock")
    }

    static var applicationSupportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(applicationSupportSubdirectory)
    }
}
