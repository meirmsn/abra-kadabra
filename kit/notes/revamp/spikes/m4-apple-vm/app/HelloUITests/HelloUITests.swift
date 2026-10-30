import XCTest

final class HelloUITests: XCTestCase {
    func testButtonUpdatesLabel() throws {
        let app = XCUIApplication()
        app.launch()
        let label = app.staticTexts["countLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 20))
        let button = app.buttons["findButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        #if os(macOS)
        button.click()
        #else
        button.tap()
        #endif
        let text = label.label + " " + ((label.value as? String) ?? "")
        print("UITEST: label after click: \(text)")
        XCTAssertTrue(text.contains("Speakers found: 2"), "label was: \(text)")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "after-click"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
