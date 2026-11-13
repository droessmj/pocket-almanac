import XCTest

@MainActor
final class DayInInkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["DAYININK_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["quick-Walk"].waitForExistence(timeout: 10))
    }

    func testProgressAccumulatesAndSurvivesRelaunch() {
        capture("Today")
        app.buttons["quick-Walk"].tap()
        app.buttons["quick-Walk"].tap()
        assertDailyTotal(2000)
        app.terminate()
        app.launch()
        assertDailyTotal(2000)
        app.buttons["tab-trends"].tap()
        XCTAssertTrue(app.buttons["90 days"].waitForExistence(timeout: 5))
        capture("Trends")
    }

    func testExplicitFailCanBeChangedToPassAndCleared() {
        app.buttons["habit-Workout"].tap()
        XCTAssertTrue(app.buttons["Check in for today"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        app.buttons["checkin-failed"].tap()
        saveAndWait()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        app.buttons["checkin-passed"].tap()
        saveAndWait()
        XCTAssertTrue(app.staticTexts["Passed"].waitForExistence(timeout: 5))
        capture("Habit detail")
        app.buttons["Check in for today"].tap()
        clearAndWait()
        XCTAssertTrue(app.staticTexts["Passed"].waitForExistence(timeout: 5))
    }

    func testDefaultPassCanBeFailedAndRestoredFromToday() {
        let quick = app.buttons["quick-Workout"]
        XCTAssertEqual(quick.label, "Mark failed for Workout")
        quick.tap()
        assertLabel(quick, equals: "Mark passed for Workout")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Workout")
        quick.tap()
        assertLabel(quick, equals: "Mark failed for Workout")
    }

    func testCreatesCustomHabit() {
        app.buttons["add-habit"].tap()
        let field = app.textFields["Habit name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Stretch")
        saveAndWait("Create")
        app.buttons["tab-habits"].tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["tab-habits"].tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 5))
    }

    func testFailedDefaultPersistsAndClearRestoresIt() {
        app.buttons["add-habit"].tap()
        let name = app.textFields["Habit name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Stretch")
        saveAndWait("Create")
        app.buttons["tab-habits"].tap()
        app.buttons["Options for Workout"].tap()
        app.buttons["Edit habit"].tap()
        let failed = app.segmentedControls["default-result"].buttons["Failed"]
        XCTAssertTrue(failed.waitForExistence(timeout: 5))
        if !failed.isHittable { app.swipeUp() }
        failed.tap()
        saveAndWait()
        app.buttons["tab-today"].tap()
        let quick = app.buttons["quick-Workout"]
        XCTAssertEqual(quick.label, "Mark passed for Workout")
        XCTAssertEqual(app.buttons["quick-Stretch"].label, "Mark failed for Stretch")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Workout")
        quick.tap()
        assertLabel(quick, equals: "Mark failed for Workout")
        app.buttons["habit-Workout"].tap()
        app.buttons["Check in for today"].tap()
        clearAndWait()
        XCTAssertTrue(app.staticTexts["Failed"].waitForExistence(timeout: 5))
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.buttons["checkin-failed"].isSelected)
        app.buttons["checkin-passed"].tap()
        saveAndWait()
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
        saveAndWait("Create")
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
        assertLabel(quick, equals: "Mark passed for Walk")
        app.terminate()
        app.launch()
        XCTAssertTrue(quick.waitForExistence(timeout: 10))
        XCTAssertEqual(quick.label, "Mark passed for Walk")
        quick.tap()
        assertLabel(quick, equals: "Mark failed for Walk")
    }

    func testCancellingTrackingChangePreservesTodaysLogAndSettings() {
        app.buttons["quick-Walk"].tap()
        chooseWalkTracking("Pass / fail")
        app.navigationBars.buttons["Save"].tap()
        let prompt = app.alerts["Change tracking for today?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.buttons["Cancel"].tap()
        XCTAssertTrue(prompt.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["tab-today"].tap()
        assertDailyTotal(1000)
        app.terminate()
        app.launch()
        assertDailyTotal(1000)
        openWalkEditor()
        XCTAssertTrue(app.segmentedControls.buttons["Build progress"].isSelected)
        app.navigationBars.buttons["Cancel"].tap()
    }

    func testConfirmedTrackingChangeUsesPassFailAndPersistsAfterRelaunch() {
        app.buttons["quick-Walk"].tap()
        chooseWalkTracking("Pass / fail")
        confirmTrackingChange()
        app.buttons["tab-today"].tap()
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.buttons["checkin-passed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["checkin-passed"].isSelected)
        XCTAssertFalse(app.textFields["Daily total"].exists)
        app.buttons["checkin-failed"].tap()
        saveAndWait()
        app.terminate()
        app.launch()
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.buttons["checkin-failed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["checkin-failed"].isSelected)
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openWalkEditor()
        XCTAssertTrue(app.segmentedControls.buttons["Pass / fail"].isSelected)
        app.navigationBars.buttons["Cancel"].tap()
    }

    func testConfirmedTrackingChangeFromPassFailToProgressStartsUnrecorded() {
        switchWalkToPassFail()
        app.buttons["tab-today"].tap()
        app.buttons["quick-Walk"].tap()
        chooseWalkTracking("Build progress")
        replace(app.textFields["Daily goal"], with: "30")
        replace(app.textFields["Progress unit"], with: "min")
        replace(app.textFields["Quick-add amount"], with: "10")
        confirmTrackingChange()
        app.buttons["tab-today"].tap()
        assertDailyTotal(0)
        app.buttons["quick-Walk"].tap()
        app.terminate()
        app.launch()
        assertDailyTotal(10)
    }

    func testDraggingHabitsAndMoveControlsPersistOrderAcrossScreens() {
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "reorder-Walk").firstMatch.exists)
        app.buttons["tab-habits"].tap()
        capture("Habits before reordering")
        dragHabit("Drink Water", onto: "Walk")
        assertHabit("Drink Water", isAbove: "Walk")
        dragHabit("Workout", onto: "Drink Water")
        assertHabit("Workout", isAbove: "Drink Water")
        dragHabit("Workout", onto: "Walk")
        assertHabit("Walk", isAbove: "Workout")
        app.buttons["Options for Walk"].tap()
        app.buttons["Move up"].tap()
        assertHabit("Walk", isAbove: "Drink Water")
        capture("Reordered Habits")
        app.terminate()
        app.launch()
        assertHabit("Walk", isAbove: "Drink Water")
        assertHabit("Drink Water", isAbove: "Workout")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "reorder-Walk").firstMatch.exists)
        capture("Prioritized Today")
        app.buttons["tab-trends"].tap()
        assertHabit("Walk", isAbove: "Drink Water")
        capture("Prioritized Trends")
    }

    private func dragHabit(_ name: String, onto target: String) {
        let handle = app.descendants(matching: .any).matching(identifier: "reorder-\(name)").firstMatch
        let destination = app.staticTexts[target].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        XCTAssertTrue(handle.isHittable)
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1,
                   thenDragTo: destination.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 1)
    }

    private func assertHabit(_ name: String, isAbove other: String) {
        let upper = app.staticTexts[name].firstMatch
        let lower = app.staticTexts[other].firstMatch
        for _ in 0..<5 where !upper.exists || !lower.exists { app.swipeUp() }
        let ordered = NSPredicate { _, _ in
            upper.exists && lower.exists && upper.frame.minY < lower.frame.minY
        }
        let expectation = XCTNSPredicateExpectation(predicate: ordered, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, app.debugDescription)
    }

    private func confirmTrackingChange() {
        app.navigationBars.buttons["Save"].tap()
        let prompt = app.alerts["Change tracking for today?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        capture("Confirm tracking change")
        prompt.buttons["confirm-tracking-change"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForNonExistence(timeout: 10))
    }

    private func switchWalkToPassFail() {
        chooseWalkTracking("Pass / fail")
        saveAndWait()
    }

    private func openWalkEditor() {
        app.buttons["tab-habits"].tap()
        app.buttons["Options for Walk"].tap()
        app.buttons["Edit habit"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Pass / fail"].waitForExistence(timeout: 5))
    }

    private func chooseWalkTracking(_ title: String) {
        openWalkEditor()
        let option = app.segmentedControls.buttons[title]
        if !option.isHittable { app.swipeUp() }
        XCTAssertTrue(option.isEnabled)
        option.tap()
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
        assertDailyTotal(2000)
    }

    func testBackupExportsAndRestoresProgressThroughFiles() {
        app.buttons["quick-Walk"].tap()
        app.buttons["quick-Walk"].tap()
        openDataTransfer()
        app.buttons["export-backup"].tap()
        let name = "DayInInkRestore-\(UUID().uuidString)"
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
        assertDailyTotal(3000)
        openDataTransfer()
        app.buttons["import-backup"].tap()
        let search = app.searchFields["Search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(name + "\n")
        let matches = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", name))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        guard let backup = matches.allElementsBoundByIndex.last(where: { $0.isHittable }) else {
            XCTFail("Exported backup is not reachable in Files search")
            return
        }
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
        assertDailyTotal(2000)
        app.terminate()
        app.launch()
        assertDailyTotal(2000)
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
        saveAndWait()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Decimal(string: total.value as? String ?? ""), Decimal(string: "0.0000004"))
        saveAndWait()
        app.terminate()
        app.launch()
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Decimal(string: total.value as? String ?? ""), Decimal(string: "0.0000004"))
    }

    private func clearAndWait() {
        let clear = app.buttons["Clear this day"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        if !clear.isHittable { app.swipeUp() }
        clear.tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForNonExistence(timeout: 10))
    }

    func testRejectsMalformedNumericTotalsAndAcceptsArabicDecimalDigits() {
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        let total = app.textFields["Daily total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        replace(total, with: "12.3.4")
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        replace(total, with: "12junk")
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        replace(total, with: "٠.٠٠٠٠٠٠٤")
        XCTAssertTrue(app.navigationBars.buttons["Save"].isEnabled)
        saveAndWait()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Decimal(string: total.value as? String ?? ""), Decimal(string: "0.0000004"))
    }

    func testCommaLocaleAcceptsPersianDigitsWithoutRounding() {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.buttons["habit-Walk"].waitForExistence(timeout: 10))
        app.buttons["habit-Walk"].tap()
        app.buttons["Check in for today"].tap()
        let total = app.textFields["Daily total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        replace(total, with: "۰,۰۰۰۰۰۰۴")
        XCTAssertTrue(app.navigationBars.buttons["Save"].isEnabled)
        saveAndWait()
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Decimal(string: total.value as? String ?? "", locale: Locale(identifier: "de_DE")),
                       Decimal(string: "0.0000004"))
    }

    func testLargestDynamicTypeKeepsLoggingAndNavigationReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tab-navigation"].waitForExistence(timeout: 10))
        let quick = app.buttons["quick-Walk"]
        for _ in 0..<8 where !quick.isHittable { app.swipeUp() }
        XCTAssertTrue(quick.isHittable)
        quick.tap()
        app.buttons["tab-navigation"].tap()
        app.buttons["tab-trends"].tap()
        let period = app.buttons["90 days"]
        for _ in 0..<8 where !period.isHittable { app.swipeUp() }
        XCTAssertTrue(period.isHittable, app.debugDescription)
        period.tap()
        XCTAssertTrue(period.isSelected)
        capture("Trends - largest text")
        app.swipeUp()
        capture("Trend card - largest text")
        app.buttons["tab-navigation"].tap()
        app.buttons["tab-habits"].tap()
        XCTAssertTrue(app.buttons["Options for Walk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["add-habit"].isHittable)
        capture("Habits - largest text")
        app.swipeUp()
        capture("Habit rows - largest text")
    }

    private func assertDailyTotal(_ expected: Decimal) {
        let habit = app.buttons["habit-Walk"]
        XCTAssertTrue(habit.waitForExistence(timeout: 10))
        habit.tap()
        app.buttons["Check in for today"].tap()
        let total = app.textFields["Daily total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(Decimal(string: total.value as? String ?? "", locale: Locale(identifier: "en_US")), expected)
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func replace(_ field: XCUIElement, with value: String) {
        for _ in 0..<5 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.isHittable)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
    }

    private func saveAndWait(_ title: String = "Save") {
        let button = app.navigationBars.buttons[title]
        button.tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 10))
    }

    private func assertLabel(_ element: XCUIElement, equals label: String) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
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
