import Foundation

public enum VaultError: Error, LocalizedError {
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case keychainKeyUnreachable
    case encryptionFailed
    case decryptionFailed
    case secretNotFound(String)
    case secretAlreadyExists(String)
    case projectNotFound(String)
    case projectAlreadyExists(String)
    case projectContainsSecrets(String)
    case environmentNotFound(String)
    case environmentAlreadyExists(String)
    case environmentContainsSecrets(String)
    case noActiveProject
    case databaseError(String)
    case invalidExportPassphrase
    case keyDerivationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .keychainReadFailed(let status):
            return "Keychain read failed (status \(status)). Try running `security unlock-keychain` if your keychain is locked."
        case .keychainWriteFailed(let status):
            return "Keychain write failed (status \(status))."
        case .keychainKeyUnreachable:
            return "A vault key already exists in the login keychain but could not be read, so it was not overwritten. Check that the login keychain is in the search list (`security list-keychains`) and unlocked, then relaunch."
        case .encryptionFailed:
            return "Failed to encrypt secret value."
        case .decryptionFailed:
            return "Failed to decrypt secret value. The vault key may have changed."
        case .secretNotFound(let name):
            return "Secret '\(name)' not found."
        case .secretAlreadyExists(let name):
            return "Secret '\(name)' already exists. Use `set` to update it."
        case .projectNotFound(let name):
            return "Project '\(name)' not found."
        case .projectAlreadyExists(let name):
            return "Project '\(name)' already exists."
        case .projectContainsSecrets(let name):
            return "Project '\(name)' contains environments or secrets and cannot be deleted."
        case .environmentNotFound(let name):
            return "Environment '\(name)' not found."
        case .environmentAlreadyExists(let name):
            return "Environment '\(name)' already exists in this project."
        case .environmentContainsSecrets(let name):
            return "Environment '\(name)' contains secret values and cannot be deleted."
        case .noActiveProject:
            return "No active project. Run `lokalite project use <name>` or `cd` into a linked project directory."
        case .databaseError(let message):
            return "Database error: \(message)"
        case .invalidExportPassphrase:
            return "Invalid passphrase for encrypted export."
        case .keyDerivationFailed(let message):
            return "Failed to derive export key: \(message)"
        }
    }
}
