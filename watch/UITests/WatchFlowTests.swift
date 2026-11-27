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

    func testFocusBriefSwitchesRunningTimer() {
        // Given I have two tasks and the first timer is running.
        let app = XCUIApplication()
        app.launchEnvironment["CRONICLE_TEST_LEDGER"] = UUID().uuidString
        app.launchEnvironment["CRONICLE_TEST_SECOND_TASK"] = "1"
        continueAfterFailure = false
        app.launch()
        app.descendants(matching: .any)["open-task-Collect probes"].firstMatch.tap()
        app.buttons["Start timer"].tap()

        // When I open the brief and switch to the next task.
        let brief = app.descendants(matching: .any)["focus-brief"].firstMatch
        for _ in 0..<3 where !brief.isHittable { app.swipeUp() }
        XCTAssertTrue(brief.isHittable, app.debugDescription)
        brief.tap()
        let next = app.descendants(matching: .any)["brief-next"].firstMatch
        if !next.isHittable { app.swipeUp() }
        XCTAssertEqual(next.label, "Check oven")
        let switchTimer = app.buttons["Switch timer"]
        if !switchTimer.isHittable { app.swipeUp() }
        XCTAssertTrue(switchTimer.isHittable, app.debugDescription)
        switchTimer.tap()

        // Then the next task persists as active and the previous task stays open.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Check oven"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["stop-timer"].firstMatch.exists)
        let previous = app.descendants(matching: .any)["open-task-Collect probes"].firstMatch
        if !previous.isHittable { app.swipeUp() }
        XCTAssertTrue(previous.isHittable)
        previous.tap()
        let time = app.descendants(matching: .any)["task-time-spent"].firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 5))
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
