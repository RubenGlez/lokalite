import Foundation
import Security

/// Generates strong random secret values for `lokalite rotate --generate`
/// (ROADMAP, P1). Uses the system CSPRNG with rejection sampling so the
/// alphabet is unbiased.
public enum SecretGenerator {
    public static let defaultLength = 32

    private static let alphabet = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    )

    public static func generate(length: Int = defaultLength) throws -> String {
        precondition(length > 0, "length must be positive")
        let count = alphabet.count
        // Reject bytes in the final, partial block so `% count` is unbiased.
        let unbiasedCeiling = 256 - (256 % count)

        var result = ""
        result.reserveCapacity(length)
        var byte = [UInt8](repeating: 0, count: 1)
        while result.count < length {
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            guard status == errSecSuccess else {
                throw VaultError.keyDerivationFailed("Failed to generate random bytes (status \(status)).")
            }
            let value = Int(byte[0])
            if value < unbiasedCeiling {
                result.append(alphabet[value % count])
            }
        }
        return result
    }
}
