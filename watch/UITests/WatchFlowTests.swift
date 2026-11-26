import XCTest

final class WatchFlowTests: XCTestCase {
    func testTimerAndCompletionSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["CRONICLE_TEST_LEDGER"] = UUID().uuidString
        continueAfterFailure = false
        app.launch()
        let openTask = app.descendants(matching: .any)["open-task-Collect probes"].firstMatch
        XCTAssertTrue(openTask.waitForExistence(timeout: 10), app.debugDescription)
        openTask.tap()
        app.buttons["Start timer"].tap()
        XCTAssertTrue(app.buttons["Stop timer"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Stop timer"].waitForExistence(timeout: 10))
        app.buttons["Stop timer"].tap()
        XCTAssertFalse(app.buttons["Stop timer"].exists)

        openTask.tap()
        let complete = app.buttons["Mark complete"]
        if !complete.isHittable { app.swipeUp() }
        complete.tap()
        XCTAssertTrue(app.descendants(matching: .any)["task-completed"].firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["completed-task-Collect probes"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Stop timer"].exists)
    }
}
