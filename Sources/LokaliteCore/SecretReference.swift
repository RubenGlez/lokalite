import Foundation

/// A `lokalite://` secret reference (ADR 0017): a committable, valueless
/// stand-in for a secret's value, resolved by `lokalite run` at spawn time.
///
/// Three forms:
/// - `lokalite://KEY` — project resolved via the linked-directory /
///   active-project rules; environment is that project's active environment
/// - `lokalite://project/KEY` — explicit project, its active environment
/// - `lokalite://project/env/KEY` — fully qualified
public struct SecretReference: Equatable, Sendable {
    public static let scheme = "lokalite://"

    public let projectName: String?
    public let environmentName: String?
    public let key: String
    /// The original reference text, kept for error reporting (never a value).
    public let text: String

    /// Whether `value` is a secret reference at all. Anything else passes
    /// through `lokalite run` untouched.
    public static func isReference(_ value: String) -> Bool {
        value.hasPrefix(scheme)
    }

    public enum ParseError: Error, LocalizedError, Equatable {
        case notAReference
        case emptySegment
        case tooManySegments

        public var errorDescription: String? {
            switch self {
            case .notAReference:
                return "not a \(SecretReference.scheme) reference"
            case .emptySegment:
                return "empty segment (expected \(SecretReference.scheme)KEY, \(SecretReference.scheme)project/KEY, or \(SecretReference.scheme)project/env/KEY)"
            case .tooManySegments:
                return "too many segments (expected \(SecretReference.scheme)KEY, \(SecretReference.scheme)project/KEY, or \(SecretReference.scheme)project/env/KEY)"
            }
        }
    }

    public init(parsing text: String) throws {
        guard Self.isReference(text) else { throw ParseError.notAReference }
        let segments = text.dropFirst(Self.scheme.count)
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard segments.allSatisfy({ !$0.isEmpty }) else { throw ParseError.emptySegment }
        switch segments.count {
        case 1:
            projectName = nil
            environmentName = nil
            key = segments[0]
        case 2:
            projectName = segments[0]
            environmentName = nil
            key = segments[1]
        case 3:
            projectName = segments[0]
            environmentName = segments[1]
            key = segments[2]
        default:
            throw ParseError.tooManySegments
        }
        self.text = text
    }
}

/// A failure to substitute one environment variable's secret reference. Names
/// the variable and the reference text — never a resolved value — so `run`
/// can fail closed without leaking anything.
public struct SecretReferenceSubstitutionError: Error, LocalizedError, Equatable {
    public let variable: String
    public let reference: String
    public let reason: String

    public init(variable: String, reference: String, reason: String) {
        self.variable = variable
        self.reference = reference
        self.reason = reason
    }

    public var errorDescription: String? {
        "cannot resolve secret reference for \(variable) (\(reference)): \(reason)"
    }
}

extension SecretReference {
    /// The `lokalite://` values in `environment`, parsed and sorted by variable
    /// name for deterministic resolution order. Throws
    /// `SecretReferenceSubstitutionError` on the first malformed reference.
    public static func scan(_ environment: [String: String]) throws -> [(variable: String, reference: SecretReference)] {
        try environment
            .filter { isReference($0.value) }
            .sorted { $0.key < $1.key }
            .map { variable, value in
                do {
                    return (variable, try SecretReference(parsing: value))
                } catch {
                    throw SecretReferenceSubstitutionError(
                        variable: variable,
                        reference: value,
                        reason: error.localizedDescription
                    )
                }
            }
    }

    /// Returns `environment` with every `lokalite://` reference replaced by the
    /// value from `resolve`; non-reference values are inherited unchanged.
    /// Fail-closed: the first malformed or unresolvable reference throws
    /// `SecretReferenceSubstitutionError` (naming the variable and the
    /// reference, never a value) and no environment is returned.
    public static func substitute(
        in environment: [String: String],
        resolve: (SecretReference) throws -> String
    ) throws -> [String: String] {
        var result = environment
        for (variable, reference) in try scan(environment) {
            do {
                result[variable] = try resolve(reference)
            } catch let error as SecretReferenceSubstitutionError {
                throw error
            } catch {
                throw SecretReferenceSubstitutionError(
                    variable: variable,
                    reference: reference.text,
                    reason: error.localizedDescription
                )
            }
        }
        return result
    }
}
