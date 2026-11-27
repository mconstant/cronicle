import XCTest

final class PhoneFlowTests: XCTestCase {
    func testCaptureTimeAndCompleteAcrossRelaunch() {
        // Given an empty offline ledger.
        let app = XCUIApplication()
        app.launchEnvironment["CRONICLE_TEST_LEDGER"] = UUID().uuidString
        app.launch()

        // When I capture a task and start its timer.
        let title = "Review tomorrow's plan"
        app.buttons["capture-task"].tap()
        let field = app.textFields["task-title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
        app.buttons["save-task"].tap()
        app.buttons["start-" + title].tap()

        // Then my timer survives relaunch, and completion survives another relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["running-task"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["running-task"].label, title)
        app.buttons["complete-running"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["completed-" + title].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["running-task"].exists)
    }
}
