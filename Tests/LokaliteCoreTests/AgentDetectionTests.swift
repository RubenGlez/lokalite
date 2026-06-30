import XCTest
@testable import LokaliteCore

final class AgentDetectionTests: XCTestCase {
    func testMatchesKnownAgentNames() {
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "claude"), "claude")
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "Cursor Helper"), "cursor")
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "windsurf"), "windsurf")
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "Codex"), "codex")
    }

    func testIgnoresNonAgents() {
        XCTAssertNil(AgentDetection.matchedAgent(processName: "zsh"))
        XCTAssertNil(AgentDetection.matchedAgent(processName: "node"))
        // Must not match a bare "code" substring.
        XCTAssertNil(AgentDetection.matchedAgent(processName: "xcodebuild"))
        XCTAssertNil(AgentDetection.matchedAgent(processName: "Terminal"))
    }

    func testWalkFromLaunchdFindsNoAgent() {
        // launchd (pid 1) has no agent ancestor; deterministic regardless of how
        // these tests are launched.
        XCTAssertNil(AgentDetection.detectAgent(startingFrom: 1))
    }

    func testWalkTerminatesAndDoesNotCrash() {
        // Whatever the result for the current tree, the walk must return.
        _ = AgentDetection.detectAgent()
    }
}
