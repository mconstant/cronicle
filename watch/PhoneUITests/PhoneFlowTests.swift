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

    func testSpokenTaskCanBeReviewedOrDiscarded() {
        let app = XCUIApplication()
        app.launchEnvironment["CRONICLE_TEST_LEDGER"] = UUID().uuidString
        app.launchEnvironment["CRONICLE_TEST_SPEECH"] = "Collect temperature probes"
        app.launch()

        app.buttons["speak-task"].tap()
        let field = app.textFields["task-title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Collect temperature probes")
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["start-Collect temperature probes"].exists)

        app.buttons["speak-task"].tap()
        XCTAssertTrue(app.buttons["save-task"].waitForExistence(timeout: 5))
        app.buttons["save-task"].tap()
        XCTAssertTrue(app.buttons["start-Collect temperature probes"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Today after voice capture"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testVoiceUnavailableKeepsTypingAvailable() {
        let app = XCUIApplication()
        app.launchEnvironment["CRONICLE_TEST_LEDGER"] = UUID().uuidString
        app.launchEnvironment["CRONICLE_TEST_SPEECH"] = ""
        app.launch()

        app.buttons["speak-task"].tap()
        let field = app.textFields["task-title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Voice access is unavailable. You can still type this task."].exists)
        field.tap()
        field.typeText("Check calendar")
        app.buttons["save-task"].tap()
        XCTAssertTrue(app.buttons["start-Check calendar"].waitForExistence(timeout: 5))
    }
}
