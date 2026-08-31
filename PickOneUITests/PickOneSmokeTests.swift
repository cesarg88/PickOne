import XCTest

final class PickOneSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMilestone7EndToEndFlow() {
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

        verifyFeedbackSurfaces(in: app)
        verifyAttribution(in: app)
        verifyRecalibration(in: app)
    }

    @MainActor
    private func verifyFeedbackSurfaces(in app: XCUIApplication) {
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
        app.navigationBars["Details"].buttons["Home"].tap()
        XCTAssertTrue(
            app.staticTexts["Recommendations updated."].waitForExistence(timeout: 15)
        )
        recommendation.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        tapButton("Mark unwatched", in: app)
        tapButton("Not interested", in: app)
        tapButton("Add to Watchlist", in: app)
        XCTAssertTrue(
            app.buttons["Remove from Watchlist"].waitForExistence(timeout: 15)
        )
        XCTAssertFalse(app.buttons["Undo Not interested"].exists)

        app.navigationBars["Details"].buttons["Home"].tap()
        app.tabBars.buttons["Watchlist"].tap()
        let watchlistRow = app.buttons["watchlist-row-101"]
        XCTAssertTrue(watchlistRow.waitForExistence(timeout: 15))
        watchlistRow.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        tapButton("Mark watched", in: app)
        app.navigationBars["Details"].buttons["Watchlist"].tap()
        XCTAssertTrue(watchlistRow.waitForNonExistence(timeout: 15))

        app.tabBars.buttons["Settings"].tap()
        tapButton("My movies", in: app)
        XCTAssertTrue(app.navigationBars["My movies"].waitForExistence(timeout: 15))
        let myMoviesRow = app.buttons["my-movies-row-101"]
        XCTAssertTrue(myMoviesRow.waitForExistence(timeout: 15))
        myMoviesRow.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Tonight's Movie"].waitForExistence(timeout: 15))
        tapButton("Love it", in: app)
        app.navigationBars["Details"].buttons["My movies"].tap()
        XCTAssertTrue(
            waitUntilLabel(
                myMoviesRow,
                equals: "Tonight's Movie, Love it",
                timeout: 15
            )
        )
        myMoviesRow.tap()
        tapButton("Mark unwatched", in: app)
        app.navigationBars["Details"].buttons["My movies"].tap()
        XCTAssertTrue(myMoviesRow.waitForNonExistence(timeout: 15))
        app.navigationBars["My movies"].buttons["Settings"].tap()
    }

    @MainActor
    private func verifyAttribution(in app: XCUIApplication) {
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
        app.navigationBars["About"].buttons["Settings"].tap()
    }

    @MainActor
    private func verifyRecalibration(in app: XCUIApplication) {
        tapButton("Repeat calibration", in: app)
        XCTAssertTrue(app.navigationBars["Repeat calibration"].waitForExistence(timeout: 15))
        tapButton("Close", in: app)
        XCTAssertTrue(app.buttons["Continue calibration"].waitForExistence(timeout: 15))
        tapButton("Continue calibration", in: app)
        for _ in 0 ..< 8 {
            tapButton("Love it", in: app)
        }
        XCTAssertTrue(app.buttons["Repeat calibration"].waitForExistence(timeout: 15))
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

    private func waitUntilLabel(
        _ element: XCUIElement,
        equals label: String,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
