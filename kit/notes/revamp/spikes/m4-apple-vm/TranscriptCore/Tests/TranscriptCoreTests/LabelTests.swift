import XCTest
@testable import TranscriptCore

final class LabelTests: XCTestCase {
    let turns = [SpeakerTurn("S1", 0, 2), SpeakerTurn("S2", 2, 4)]

    func testWordGoesToTheTurnItOverlapsMost() {
        let out = label(words: [Word("hello", 0.1, 0.5), Word("there", 1.8, 2.5)], turns: turns)
        XCTAssertEqual(out.map(\.speaker), ["S1", "S2"])
    }

    func testWordInAGapGoesToTheNearestTurn() {
        let out = label(words: [Word("late", 4.3, 4.6)], turns: turns)
        XCTAssertEqual(out.map(\.speaker), ["S2"])
    }

    func testRenderGroupsRunsOfOneSpeaker() {
        let words = [LabelledWord(text: "hi", speaker: "S1"), LabelledWord(text: "all", speaker: "S1"),
                     LabelledWord(text: "hello", speaker: "S2")]
        XCTAssertEqual(render(words), "S1: hi all\nS2: hello")
    }

    func testNoTurnsMarksSpeakerUnknown() {
        XCTAssertEqual(label(words: [Word("x", 0, 1)], turns: []).map(\.speaker), ["?"])
    }
}
