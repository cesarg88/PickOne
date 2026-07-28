import XCTest

final class PickOneSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMainTabsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        let tabs = ["Discover", "Search", "Ask", "Watchlist"]

        let aboutButton = app.buttons["About"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 5))
        aboutButton.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["The Movie Database"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "This product uses the TMDB API but is not endorsed or certified by TMDB."
            ].exists
        )
        app.buttons["Done"].tap()

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(tab) tab is missing")
            button.tap()
            XCTAssertTrue(button.isSelected, "\(tab) tab did not become selected")
        }
    }
}
