import XCTest

final class PickOneSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMilestone7EndToEndFlow() {
        let app = launchReadyApp()

        let tabs = ["Home", "Search", "Discover", "Watchlist", "Settings"]

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 15), "\(tab) tab is missing")
            button.tap()
            XCTAssertTrue(button.isSelected, "\(tab) tab did not become selected")
        }

        XCTAssertFalse(app.tabBars.buttons["Ask"].exists, "Ask should not be exposed as a tab")

        verifyHomeQuickFeedback(in: app)
        verifyFeedbackSurfaces(in: app)
        verifyAttribution(in: app)
        verifyRecalibration(in: app)
    }

    @MainActor
    func testHomeQuickFeedbackFailureCanRetryAtAccessibilityTextSize() {
        let app = launchReadyApp(extraArguments: [
            "-ui-testing-home-feedback-fails-once",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        let recommendation = app.buttons["home-recommendation-101"]
        let feedbackMenu = app.buttons["Feedback for Tonight's Movie"]
        XCTAssertTrue(recommendation.waitForExistence(timeout: 15))
        XCTAssertTrue(feedbackMenu.waitForExistence(timeout: 15))
        XCTAssertTrue(feedbackMenu.isHittable)

        feedbackMenu.tap()
        XCTAssertFalse(app.navigationBars["Details"].exists)
        tapButton("Not interested", in: app)

        let alert = app.alerts["Couldn't save feedback"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts["Your feedback wasn't saved. Please try again."].exists)
        XCTAssertTrue(alert.buttons["Try again"].exists)
        XCTAssertTrue(alert.buttons["Cancel"].exists)
        XCTAssertTrue(recommendation.exists, "A failed write must preserve the card")

        alert.buttons["Try again"].tap()
        XCTAssertTrue(recommendation.waitForNonExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home-recommendation-202"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.navigationBars["Details"].exists)
    }

    @MainActor
    func testMilestone7P0UpgradeQuickFeedbackAndRelaunchJourney() {
        let app = launchM7P0ClosureApp(resetting: true)
        defer { cleanM7P0ClosureScenario(runningApp: app) }

        XCTAssertTrue(app.buttons["home-recommendation-101"].waitForExistence(timeout: 15))
        verifyM7P0PreservedSurfaces(in: app)

        app.tabBars.buttons["Home"].tap()
        let feedbackMenu = app.buttons["Feedback for Tonight's Movie"]
        XCTAssertTrue(feedbackMenu.waitForExistence(timeout: 15))
        feedbackMenu.tap()
        tapButton("Already watched", in: app)
        XCTAssertTrue(
            app.buttons["home-recommendation-202"].waitForExistence(timeout: 15)
        )
        XCTAssertFalse(app.navigationBars["Details"].exists)

        app.tabBars.buttons["Settings"].tap()
        tapButton("My movies", in: app)
        XCTAssertTrue(app.buttons["my-movies-row-101"].waitForExistence(timeout: 15))

        app.terminate()
        let relaunched = launchM7P0ClosureApp(resetting: false)

        XCTAssertTrue(
            relaunched.buttons["home-recommendation-202"].waitForExistence(timeout: 15)
        )
        XCTAssertFalse(relaunched.buttons["home-recommendation-101"].exists)
        verifyM7P0PreservedSurfaces(in: relaunched)
        relaunched.tabBars.buttons["Settings"].tap()
        tapButton("My movies", in: relaunched)
        XCTAssertTrue(
            relaunched.buttons["my-movies-row-101"].waitForExistence(timeout: 15)
        )
        relaunched.terminate()
    }

    @MainActor
    private func launchReadyApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launchArguments.append("-ui-testing-reset-viewer-profile")
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()

        XCTAssertTrue(app.staticTexts["Streaming services"].waitForExistence(timeout: 15))
        tapButton("Netflix", in: app)
        tapButton("Continue", in: app)

        for _ in 0 ..< 8 {
            tapButton("Love it", in: app)
        }
        return app
    }

    @MainActor
    private func launchM7P0ClosureApp(resetting: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-m7-p0-closure"]
        if resetting {
            app.launchArguments.append("-ui-testing-m7-p0-closure-reset")
        }
        app.launch()
        return app
    }

    @MainActor
    private func cleanM7P0ClosureScenario(runningApp: XCUIApplication) {
        runningApp.terminate()
        let cleanup = XCUIApplication()
        cleanup.launchArguments = [
            "-ui-testing",
            "-ui-testing-m7-p0-closure",
            "-ui-testing-m7-p0-closure-cleanup",
        ]
        cleanup.launch()
        cleanup.terminate()
    }

    @MainActor
    private func verifyM7P0PreservedSurfaces(in app: XCUIApplication) {
        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.buttons["watchlist-row-303"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["Sanitized Query"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func verifyHomeQuickFeedback(in app: XCUIApplication) {
        app.tabBars.buttons["Home"].tap()
        let recommendation = app.buttons["home-recommendation-101"]
        let feedbackMenu = app.buttons["Feedback for Tonight's Movie"]
        XCTAssertTrue(recommendation.waitForExistence(timeout: 15))
        XCTAssertTrue(feedbackMenu.waitForExistence(timeout: 15))

        feedbackMenu.tap()
        XCTAssertFalse(app.navigationBars["Details"].exists)
        for action in [
            "Love it",
            "Like it",
            "It was okay",
            "Didn't like it",
            "Already watched",
            "Not interested",
        ] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 15), "\(action) is missing")
        }

        tapButton("Already watched", in: app)
        XCTAssertTrue(recommendation.waitForNonExistence(timeout: 15))
        XCTAssertTrue(app.buttons["home-recommendation-202"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.navigationBars["Details"].exists)
    }

    @MainActor
    private func verifyFeedbackSurfaces(in app: XCUIApplication) {
        app.tabBars.buttons["Home"].tap()
        let recommendation = app.buttons["home-recommendation-202"]
        XCTAssertTrue(
            recommendation.waitForExistence(timeout: 15),
            "Home recommendation did not load"
        )
        recommendation.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Replacement Movie"].waitForExistence(timeout: 15))
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

        app.navigationBars["Details"].buttons["Home"].tap()
        XCTAssertTrue(
            app.staticTexts["Recommendations updated."].waitForExistence(timeout: 15)
        )
        app.tabBars.buttons["Watchlist"].tap()
        let watchlistRow = app.buttons["watchlist-row-202"]
        XCTAssertTrue(watchlistRow.waitForExistence(timeout: 15))
        watchlistRow.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        tapButton("Mark watched", in: app)
        app.navigationBars["Details"].buttons["Watchlist"].tap()
        XCTAssertTrue(watchlistRow.waitForNonExistence(timeout: 15))

        app.tabBars.buttons["Settings"].tap()
        tapButton("My movies", in: app)
        XCTAssertTrue(app.navigationBars["My movies"].waitForExistence(timeout: 15))
        let myMoviesRow = app.buttons["my-movies-row-202"]
        XCTAssertTrue(myMoviesRow.waitForExistence(timeout: 15))
        myMoviesRow.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Replacement Movie"].waitForExistence(timeout: 15))
        tapButton("Love it", in: app)
        app.navigationBars["Details"].buttons["My movies"].tap()
        XCTAssertTrue(
            waitUntilLabel(
                myMoviesRow,
                equals: "Replacement Movie, Love it",
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
        for _ in 0 ..< 6 where !button.exists {
            app.swipeUp()
        }
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
