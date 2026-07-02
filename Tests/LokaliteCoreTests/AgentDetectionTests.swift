import XCTest
@testable import LokaliteCore

final class AgentDetectionTests: XCTestCase {
    func testMatchesKnownAgentNames() {
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "claude"), "claude")
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "Cursor Helper"), "cursor")
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "windsurf"), "windsurf")
        XCTAssertEqual(AgentDetection.matchedAgent(processName: "Codex"), "codex")
    }

    func testMatchesAgentInExecutablePath() {
        // Claude Code's kernel process name is a bare version number (p_comm
        // "2.1.198"); only the executable path identifies the agent. The walk
        // feeds paths through the same matcher.
        XCTAssertEqual(
            AgentDetection.matchedAgent(processName: "/Users/dev/.local/share/claude/versions/2.1.198"),
            "claude"
        )
        XCTAssertEqual(
            AgentDetection.matchedAgent(processName: "/Applications/Cursor.app/Contents/MacOS/Cursor"),
            "cursor"
        )
        XCTAssertNil(AgentDetection.matchedAgent(processName: "/usr/bin/xcodebuild"))
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
