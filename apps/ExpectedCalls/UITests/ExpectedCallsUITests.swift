import XCTest

final class ExpectedCallsUITests: XCTestCase {
    @MainActor
    func testQueuedWindowPersistsAndEditingInvalidatesSetup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--expected-calls-ui-testing", "--expected-calls-reset-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["add-window"].waitForExistence(timeout: 10))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "window-"))
        let initialCount = rows.count
        app.buttons["add-window"].tap()
        let label = app.textFields["window-label"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        if let value = label.value as? String, !value.isEmpty {
            label.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        label.typeText("Future callback")
        app.buttons["save-window"].tap()
        XCTAssertTrue(app.buttons["add-window"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, initialCount + 1)
        app.terminate()
        app.launchArguments = ["--expected-calls-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["add-window"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, initialCount + 1)
        let callback = rows.containing(NSPredicate(format: "label CONTAINS %@", "Future callback")).firstMatch
        XCTAssertTrue(callback.exists)
        callback.tap()
        app.buttons["setup-window"].tap()
        let confirmation = app.buttons["confirm-setup"]
        for _ in 0..<12 where !confirmation.isHittable { app.swipeUp() }
        XCTAssertTrue(confirmation.isHittable)
        confirmation.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "setup-status").firstMatch.value as? String, "confirmed")
        let edit = app.buttons["edit-window"]
        for _ in 0..<8 where !edit.isHittable { app.swipeUp() }
        XCTAssertTrue(edit.isHittable)
        edit.tap()
        let editedLabel = app.textFields["window-label"]
        XCTAssertTrue(editedLabel.waitForExistence(timeout: 5))
        editedLabel.tap()
        editedLabel.typeText(" revised")
        app.buttons["save-window"].tap()
        let status = app.staticTexts.matching(identifier: "setup-status").firstMatch
        for _ in 0..<8 where !status.exists { app.swipeDown() }
        XCTAssertEqual(app.staticTexts.matching(identifier: "setup-status").firstMatch.value as? String, "needsSetup")
    }
}
