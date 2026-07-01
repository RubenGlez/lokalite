import XCTest
@testable import LokaliteCore

final class SecretGeneratorTests: XCTestCase {
    private let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    func testGeneratesRequestedLength() throws {
        XCTAssertEqual(try SecretGenerator.generate(length: 24).count, 24)
        XCTAssertEqual(try SecretGenerator.generate().count, SecretGenerator.defaultLength)
    }

    func testUsesOnlyAlphanumericCharacters() throws {
        // A long draw exercises the rejection-sampling loop across the alphabet.
        let value = try SecretGenerator.generate(length: 500)
        XCTAssertTrue(value.allSatisfy { alphabet.contains($0) })
    }

    func testProducesDifferentValues() throws {
        XCTAssertNotEqual(try SecretGenerator.generate(), try SecretGenerator.generate())
    }
}
