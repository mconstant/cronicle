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
        let stop = app.descendants(matching: .any)["stop-timer"].firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 8), app.debugDescription)

        app.terminate()
        app.launch()
        XCTAssertTrue(stop.waitForExistence(timeout: 10), app.debugDescription)
        stop.tap()
        XCTAssertTrue(openTask.waitForExistence(timeout: 5))
        XCTAssertFalse(stop.exists)

        openTask.tap()
        let complete = app.buttons["Mark complete"]
        if !complete.isHittable { app.swipeUp() }
        complete.tap()
        let completed = app.descendants(matching: .any)["completed-task-Collect probes"].firstMatch
        if !completed.isHittable { app.swipeUp() }
        XCTAssertTrue(completed.waitForExistence(timeout: 8), app.debugDescription)

        app.terminate()
        app.launch()
        if !completed.isHittable { app.swipeUp() }
        XCTAssertTrue(completed.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(stop.exists)
    }
}
