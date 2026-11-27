import XCTest

final class WatchFlowTests: XCTestCase {
    func testFocusBriefStartsNextTask() {
        let app = XCUIApplication()
        app.launchEnvironment["CRONICLE_TEST_LEDGER"] = UUID().uuidString
        continueAfterFailure = false
        app.launch()
        let brief = app.descendants(matching: .any)["focus-brief"].firstMatch
        if !brief.isHittable { app.swipeUp() }
        XCTAssertTrue(brief.waitForExistence(timeout: 10), app.debugDescription)
        brief.tap()
        let next = app.descendants(matching: .any)["brief-next"].firstMatch
        if !next.isHittable { app.swipeUp() }
        XCTAssertTrue(next.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertEqual(next.label, "Collect probes")
        let start = app.descendants(matching: .any)["brief-start"].firstMatch
        if !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["stop-timer"].firstMatch.waitForExistence(timeout: 10))
    }

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
