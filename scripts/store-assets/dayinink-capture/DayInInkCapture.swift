import XCTest
import Foundation

@MainActor
final class DayInInkCapture: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.droessmj.dayinink")
    private let endpoint = "http://127.0.0.1:8871"

    private func host(_ path: String) {
        let completed = expectation(description: path)
        URLSession.shared.dataTask(with: URL(string: endpoint + path)!) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 30)
    }

    private func settle(_ seconds: TimeInterval = 1.2) { Thread.sleep(forTimeInterval: seconds) }
    private func capture(_ name: String) { settle(); host("/screenshot/" + name) }

    func testCaptureStoreAssets() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["quick-Walk"].waitForExistence(timeout: 15))
        settle(2)
        capture("01-today")
        host("/record/start")
        settle(2)
        app.buttons["quick-Walk"].tap()
        settle(2)
        app.buttons["habit-Walk"].tap()
        XCTAssertTrue(app.buttons["Check in for today"].waitForExistence(timeout: 5))
        settle(3)
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.textFields["Daily total"].waitForExistence(timeout: 5))
        settle(2)
        app.navigationBars.buttons["Cancel"].tap()
        settle(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab-trends"].tap()
        XCTAssertTrue(app.buttons["90 days"].waitForExistence(timeout: 5))
        settle(3)
        app.buttons["90 days"].tap()
        settle(2)
        app.buttons["tab-habits"].tap()
        settle(2)
        host("/record/stop")
        app.buttons["tab-today"].tap()
        app.buttons["habit-Walk"].tap()
        XCTAssertTrue(app.buttons["Check in for today"].waitForExistence(timeout: 5))
        capture("02-habit-progress")
        app.buttons["Check in for today"].tap()
        XCTAssertTrue(app.textFields["Daily total"].waitForExistence(timeout: 5))
        capture("03-check-in")
        app.navigationBars.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab-trends"].tap()
        app.buttons["30 days"].tap()
        capture("04-trends")
        app.buttons["tab-habits"].tap()
        capture("05-your-habits")
        app.buttons["Options for Walk"].tap()
        app.buttons["Edit habit"].tap()
        XCTAssertTrue(app.textFields["Habit name"].waitForExistence(timeout: 5))
        capture("06-make-it-yours")
        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["tab-today"].tap()
    }
}
