import XCTest

@MainActor
final class DaymarkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["DAYMARK_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["quick-Walk"].waitForExistence(timeout: 10))
    }

    func testProgressAccumulatesAndSurvivesRelaunch() {
        capture("Today")
        app.buttons["quick-Walk"].tap()
        app.buttons["quick-Walk"].tap()
        XCTAssertTrue(app.staticTexts["2,000 / 10,000 steps"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["2,000 / 10,000 steps"].waitForExistence(timeout: 10))
        app.buttons["tab-trends"].tap()
        XCTAssertTrue(app.staticTexts["Little steps add up."].waitForExistence(timeout: 5))
        capture("Trends")
    }

    func testExplicitFailCanBeChangedToPassAndCleared() {
        app.buttons["habit-Mind clearing"].tap()
        XCTAssertTrue(app.buttons["Check in for today"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        app.buttons["checkin-failed"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        app.buttons["checkin-passed"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Passed"].waitForExistence(timeout: 5))
        capture("Habit detail")
        app.buttons["Check in for today"].tap()
        app.buttons["Clear this day"].tap()
        XCTAssertTrue(app.staticTexts["Passed"].waitForExistence(timeout: 5))
    }

    func testDefaultPassCanBeFailedAndRestoredFromToday() {
        let quick = app.buttons["quick-Mind clearing"]
        XCTAssertEqual(quick.label, "Mark failed for Mind clearing")
        quick.tap()
        XCTAssertEqual(quick.label, "Mark passed for Mind clearing")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Mind clearing")
        quick.tap()
        XCTAssertEqual(quick.label, "Mark failed for Mind clearing")
    }

    func testCreatesCustomHabit() {
        app.buttons["add-habit"].tap()
        let field = app.textFields["Habit name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Stretch")
        app.navigationBars.buttons["Create"].tap()
        app.buttons["tab-habits"].tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["tab-habits"].tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
