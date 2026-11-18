import XCTest
@testable import IntervalCore

final class LabelTests: XCTestCase {
    let spans = [Span("A", 0, 2), Span("B", 2, 4)]

    func testItemGoesToTheSpanItOverlapsMost() {
        let out = label(items: [Item("hello", 0.1, 0.5), Item("there", 1.8, 2.5)], spans: spans)
        XCTAssertEqual(out.map(\.label), ["A", "B"])
    }

    func testItemInAGapGoesToTheNearestSpan() {
        let out = label(items: [Item("late", 4.3, 4.6)], spans: spans)
        XCTAssertEqual(out.map(\.label), ["B"])
    }

    func testRenderGroupsRunsOfOneLabel() {
        let items = [LabelledItem(text: "hi", label: "A"), LabelledItem(text: "all", label: "A"),
                     LabelledItem(text: "hello", label: "B")]
        XCTAssertEqual(render(items), "A: hi all\nB: hello")
    }

    func testNoSpansMarksLabelUnknown() {
        XCTAssertEqual(label(items: [Item("x", 0, 1)], spans: []).map(\.label), ["?"])
    }
}
