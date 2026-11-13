import XCTest

@MainActor
final class BlotterStoreCapture: XCTestCase {
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "blotter-" + name
        image.lifetime = .keepAlways
        add(image)
    }

    private func changeOption(_ label: String, in app: XCUIApplication) {
        let control = app.switches[label]
        if control.frame.maxY > app.frame.maxY - 80 {
            app.swipeUp()
        }
        let before = control.value as? String
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (control.value as? String) != before
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed, "Matching option must visibly change: \(label)")
    }

    func testCaptureStoreAssets() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.droessmj.blotter")
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 15))
        sleep(2)
        capture("01-setup")
        app.buttons["Get started"].tap()
        let field = app.textFields["Add keyword or phrase"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        for keyword in ["prize claim", "limited offer", "vote"] {
            field.tap()
            field.typeText(keyword)
            app.buttons["Add"].tap()
        }
        if app.keyboards.count > 0 { app.swipeDown() }
        app.terminate()
        app.launch()
        sleep(2)
        capture("02-keywords")
        // The parent starts/stops simctl recording around this capture-only test.
        // Attachments identify the meaningful recording interval, without fabricating UI.
        capture("preview-start")
        sleep(2)
        field.tap()
        field.typeText("cash reward")
        sleep(1)
        field.typeText("\n")
        sleep(2)
        changeOption("Match case", in: app)
        sleep(2)
        changeOption("Match accents", in: app)
        sleep(2)
        changeOption("Whole words only", in: app)
        sleep(2)
        capture("03-matching-options")
        app.swipeUp()
        sleep(3)
        capture("04-keywords-and-privacy-links")
        sleep(2)
        capture("preview-end")
    }

    func testRecaptureOptionsPreview() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.droessmj.blotter")
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.textFields["Add keyword or phrase"].waitForExistence(timeout: 15))
        app.swipeDown()
        sleep(1)
        capture("preview-start")
        sleep(2)
        let field = app.textFields["Add keyword or phrase"]
        field.tap()
        field.typeText("bonus offer")
        sleep(1)
        field.typeText("\n")
        sleep(1)
        changeOption("Match case", in: app)
        sleep(2)
        changeOption("Match accents", in: app)
        sleep(2)
        changeOption("Whole words only", in: app)
        sleep(2)
        capture("03-matching-options")
        app.swipeUp()
        sleep(3)
        XCTAssertTrue(app.staticTexts["bonus offer"].exists)
        capture("04-keywords-and-privacy-links")
        sleep(2)
        capture("preview-end")
    }
}
