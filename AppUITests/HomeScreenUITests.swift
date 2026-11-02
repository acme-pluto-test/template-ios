import XCTest

final class HomeScreenUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    func testShowsTitleAndOpensWebApp() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Pluto"].waitForExistence(timeout: 10))
        let open = app.buttons["Open web app"]
        XCTAssertTrue(open.exists)
        open.tap()
        XCTAssertTrue(app.otherElements["web-screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Open web app"].exists, "the home screen is covered by the web screen")
    }

    func testShowsFailedPageAndTriesAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-failed"]
        app.launch()
        app.buttons["Open web app"].tap()
        XCTAssertTrue(app.staticTexts["The page could not be loaded"].waitForExistence(timeout: 10))
        let retry = app.buttons["Try again"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertFalse(app.staticTexts["The page could not be loaded"].waitForExistence(timeout: 2), "retrying goes back to loading")
    }

    func testReturnsToHomeOnBack() {
        let app = launch()
        app.buttons["Open web app"].tap()
        XCTAssertTrue(app.otherElements["web-screen"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Pluto"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open web app"].exists)
    }
}
