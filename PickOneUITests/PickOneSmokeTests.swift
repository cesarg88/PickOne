import XCTest

final class PickOneSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMainTabsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launchArguments.append("-ui-testing-reset-viewer-profile")
        app.launch()

        XCTAssertTrue(app.staticTexts["Streaming services"].waitForExistence(timeout: 15))
        tapButton("Netflix", in: app)
        tapButton("Continue", in: app)

        for _ in 0 ..< 8 {
            tapButton("Love it", in: app)
        }

        let tabs = ["Home", "Search", "Discover", "Watchlist", "Settings"]

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 15), "\(tab) tab is missing")
            button.tap()
            XCTAssertTrue(button.isSelected, "\(tab) tab did not become selected")
        }

        XCTAssertFalse(app.tabBars.buttons["Ask"].exists, "Ask should not be exposed as a tab")

        app.tabBars.buttons["Home"].tap()
        let recommendation = app.buttons["home-recommendation-101"]
        XCTAssertTrue(
            recommendation.waitForExistence(timeout: 15),
            "Home recommendation did not load"
        )
        recommendation.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Tonight's Movie"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.otherElements["movie-feedback-section"].waitForExistence(timeout: 15)
        )
        tapButton("Love it", in: app)
        tapButton("Mark unwatched", in: app)
        tapButton("Not interested", in: app)
        tapButton("Add to Watchlist", in: app)
        XCTAssertTrue(
            app.buttons["Remove from Watchlist"].waitForExistence(timeout: 15)
        )
        XCTAssertFalse(app.buttons["Undo Not interested"].exists)

        app.tabBars.buttons["Settings"].tap()
        app.buttons["About"].tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.images["The Movie Database"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "This product uses the TMDB API but is not endorsed or certified by TMDB."
            ].exists
        )
        XCTAssertTrue(
            app.staticTexts[
                "Streaming availability data is provided by JustWatch."
            ].exists
        )
    }

    @MainActor
    private func tapButton(
        _ label: String,
        in app: XCUIApplication
    ) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(label) is missing")
        XCTAssertTrue(
            waitUntilEnabled(button, timeout: 15),
            "\(label) did not become enabled"
        )
        for _ in 0 ..< 4 where !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.isHittable, "\(label) is not hittable")
        button.tap()
    }

    private func waitUntilEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
