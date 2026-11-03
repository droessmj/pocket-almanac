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

    func testFailedDefaultPersistsAndClearRestoresIt() {
        app.buttons["tab-habits"].tap()
        app.buttons["Options for Mind clearing"].tap()
        app.buttons["Edit habit"].tap()
        let failed = app.segmentedControls["default-result"].buttons["Failed"]
        XCTAssertTrue(failed.waitForExistence(timeout: 5))
        if !failed.isHittable { app.swipeUp() }
        failed.tap()
        app.navigationBars.buttons["Save"].tap()
        app.buttons["tab-today"].tap()
        let quick = app.buttons["quick-Mind clearing"]
        XCTAssertEqual(quick.label, "Mark passed for Mind clearing")
        XCTAssertEqual(app.buttons["quick-No snack after dinner"].label, "Mark failed for No snack after dinner")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Mind clearing")
        quick.tap()
        XCTAssertEqual(quick.label, "Mark failed for Mind clearing")
        app.buttons["habit-Mind clearing"].tap()
        app.buttons["Check in for today"].tap()
        app.buttons["Clear this day"].tap()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.buttons["checkin-failed"].isSelected)
        app.buttons["checkin-passed"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Passed"].waitForExistence(timeout: 5))
    }

    func testCreatesPassFailHabitWithFailedDefault() {
        app.buttons["add-habit"].tap()
        let field = app.textFields["Habit name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Practice")
        app.swipeUp()
        let failed = app.segmentedControls["default-result"].buttons["Failed"]
        XCTAssertTrue(failed.waitForExistence(timeout: 5))
        if !failed.isHittable { app.swipeUp() }
        failed.tap()
        app.navigationBars.buttons["Create"].tap()
        let quick = app.buttons["quick-Practice"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5))
        XCTAssertEqual(quick.label, "Mark passed for Practice")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Practice")
    }

    func testSwitchesUnrecordedProgressHabitToPassFail() {
        switchWalkToPassFail()
        app.buttons["tab-today"].tap()
        let quick = app.buttons["quick-Walk"]
        XCTAssertEqual(quick.label, "Mark failed for Walk")
        quick.tap()
        XCTAssertEqual(quick.label, "Mark passed for Walk")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Walk")
        quick.tap()
        XCTAssertEqual(quick.label, "Mark failed for Walk")
    }

    func testSwitchingTrackingPreservesRecordedProgressUntilCleared() {
        app.buttons["quick-Walk"].tap()
        switchWalkToPassFail()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["1,000 / 10,000 steps"].waitForExistence(timeout: 10))
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        let total = app.textFields["Daily total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        app.buttons["+1"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["1,001 / 10,000 steps"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        let clear = app.buttons["Clear this day"]
        if !clear.isHittable { app.swipeUp() }
        clear.tap()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.buttons["checkin-failed"].waitForExistence(timeout: 5))
        app.buttons["checkin-failed"].tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["quick-Walk"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["quick-Walk"].label, "Mark passed for Walk")
    }

    private func switchWalkToPassFail() {
        app.buttons["tab-habits"].tap()
        app.buttons["Options for Walk"].tap()
        app.buttons["Edit habit"].tap()
        let passFail = app.segmentedControls.buttons["Pass / fail"]
        XCTAssertTrue(passFail.waitForExistence(timeout: 5))
        if !passFail.isHittable { app.swipeUp() }
        XCTAssertTrue(passFail.isEnabled)
        passFail.tap()
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Daily · pass / fail"].firstMatch.waitForExistence(timeout: 5))
    }

    func testBackupPickersCanBeCancelledWithoutChangingProgress() {
        app.buttons["quick-Walk"].tap()
        app.buttons["quick-Walk"].tap()
        app.buttons["tab-habits"].tap()
        app.buttons["About Day in Ink and your data"].tap()
        app.buttons["data-transfer"].tap()
        let export = app.buttons["export-backup"]
        let importBackup = app.buttons["import-backup"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(importBackup.exists)
        export.tap()
        let save = app.buttons["DOCPicker.actionButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        // Export opens inside a folder without a visible Cancel control; dismiss its sheet.
        let bar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertTrue(importBackup.waitForExistence(timeout: 5))
        importBackup.tap()
        let cancel = app.buttons.matching(identifier: "Cancel").firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons["Done"].tap()
        app.buttons["tab-today"].tap()
        XCTAssertTrue(app.staticTexts["2,000 / 10,000 steps"].waitForExistence(timeout: 5))
    }

    func testBackupExportsAndRestoresProgressThroughFiles() {
        app.buttons["quick-Walk"].tap()
        app.buttons["quick-Walk"].tap()
        openDataTransfer()
        app.buttons["export-backup"].tap()
        let name = "DaymarkRestore-\(UUID().uuidString)"
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let previous = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + name)
        app.buttons["DOCPicker.actionButton"].tap()
        XCTAssertTrue(app.alerts["Backup exported"].waitForExistence(timeout: 10))
        app.alerts["Backup exported"].buttons["OK"].tap()
        closeDataTransfer()
        app.buttons["tab-today"].tap()
        app.buttons["quick-Walk"].tap()
        XCTAssertTrue(app.staticTexts["3,000 / 10,000 steps"].exists)
        openDataTransfer()
        app.buttons["import-backup"].tap()
        let backup = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(backup.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(backup.isEnabled)
        capture("Import picker")
        backup.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        let review = app.buttons["confirm-import"]
        XCTAssertTrue(review.waitForExistence(timeout: 10), app.debugDescription)
        review.tap()
        let replace = app.buttons["Replace all data"]
        XCTAssertTrue(replace.waitForExistence(timeout: 10))
        replace.tap()
        XCTAssertTrue(app.alerts["Backup imported"].waitForExistence(timeout: 10))
        app.alerts["Backup imported"].buttons["OK"].tap()
        closeDataTransfer()
        app.buttons["tab-today"].tap()
        XCTAssertTrue(app.staticTexts["2,000 / 10,000 steps"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["2,000 / 10,000 steps"].waitForExistence(timeout: 10))
    }

    func testSmallExactTotalSurvivesReopeningAndSavingUnchanged() {
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        let total = app.textFields["Daily total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        total.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let previous = total.value as? String ?? ""
        total.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "0.0000004")
        XCTAssertTrue(app.navigationBars.buttons["Save"].isEnabled, app.debugDescription)
        app.navigationBars.buttons["Save"].tap()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Double(total.value as? String ?? ""), 0.0000004)
        app.navigationBars.buttons["Save"].tap()
        app.terminate()
        app.launch()
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Double(total.value as? String ?? ""), 0.0000004)
    }

    private func openDataTransfer() {
        app.buttons["tab-habits"].tap()
        app.buttons["About Day in Ink and your data"].tap()
        app.buttons["data-transfer"].tap()
        XCTAssertTrue(app.buttons["export-backup"].waitForExistence(timeout: 5))
    }

    private func closeDataTransfer() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons["Done"].tap()
    }


    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
