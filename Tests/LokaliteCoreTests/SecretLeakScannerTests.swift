import XCTest
@testable import LokaliteCore

final class SecretLeakScannerTests: XCTestCase {
    func testRedactsAKnownValue() {
        let scanner = SecretLeakScanner(secrets: [("OPENAI_API_KEY", "sk-abc123456789")])
        let result = scanner.scan("the key is sk-abc123456789 ok")
        XCTAssertTrue(result.hasLeaks)
        XCTAssertEqual(result.redactedText, "the key is [redacted:OPENAI_API_KEY] ok")
        XCTAssertEqual(result.findings, [.init(secretNames: ["OPENAI_API_KEY"], occurrences: 1)])
    }

    func testCleanTextPassesThroughUnchanged() {
        let scanner = SecretLeakScanner(secrets: [("TOKEN", "supersecretvalue")])
        let result = scanner.scan("nothing to see here")
        XCTAssertFalse(result.hasLeaks)
        XCTAssertEqual(result.redactedText, "nothing to see here")
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testCountsMultipleOccurrences() {
        let scanner = SecretLeakScanner(secrets: [("TOKEN", "abcdef123")])
        let result = scanner.scan("abcdef123 and again abcdef123")
        XCTAssertEqual(result.findings.first?.occurrences, 2)
        XCTAssertEqual(result.redactedText, "[redacted:TOKEN] and again [redacted:TOKEN]")
    }

    func testIgnoresShortValues() {
        // Below minimumValueLength — must not redact to avoid false positives.
        let scanner = SecretLeakScanner(secrets: [("ENV", "dev")])
        let result = scanner.scan("running in dev mode")
        XCTAssertFalse(result.hasLeaks)
        XCTAssertEqual(result.redactedText, "running in dev mode")
    }

    func testRedactsLongestValueFirstWhenOverlapping() {
        // A shorter value that is a substring of a longer one must not pre-empt
        // the longer, more specific match.
        let scanner = SecretLeakScanner(secrets: [
            ("SHORT", "secret1234"),
            ("LONG", "secret1234567890"),
        ])
        let result = scanner.scan("value=secret1234567890")
        XCTAssertEqual(result.redactedText, "value=[redacted:LONG]")
    }

    func testGroupsSecretsSharingTheSameValue() {
        let scanner = SecretLeakScanner(secrets: [
            ("A", "sharedvalue1"),
            ("B", "sharedvalue1"),
        ])
        let result = scanner.scan("leak: sharedvalue1")
        XCTAssertEqual(result.redactedText, "leak: [redacted:A|B]")
        XCTAssertEqual(result.findings, [.init(secretNames: ["A", "B"], occurrences: 1)])
    }

    func testDeduplicatesRepeatedNameValuePairs() {
        // The same secret can appear once per environment with the same value;
        // its name should not be listed twice.
        let scanner = SecretLeakScanner(secrets: [
            ("TOKEN", "duplicated123"),
            ("TOKEN", "duplicated123"),
        ])
        let result = scanner.scan("x duplicated123")
        XCTAssertEqual(result.redactedText, "x [redacted:TOKEN]")
    }
}
