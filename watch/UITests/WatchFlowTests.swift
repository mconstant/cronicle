import XCTest

final class WatchFlowTests: XCTestCase {
    func testTimerAndCompletionSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-ledger", UUID().uuidString]
        app.launch()
        let openTask = app.staticTexts["Collect probes"]
        XCTAssertTrue(openTask.waitForExistence(timeout: 10))
        openTask.tap()
        app.buttons["Start timer"].tap()
        XCTAssertTrue(app.buttons["Stop timer"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Stop timer"].waitForExistence(timeout: 10))
        app.buttons["Stop timer"].tap()
        XCTAssertFalse(app.buttons["Stop timer"].exists)

        app.staticTexts["Collect probes"].tap()
        let complete = app.buttons["Mark complete"]
        if !complete.isHittable { app.swipeUp() }
        complete.tap()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Stop timer"].exists)
    }
}
