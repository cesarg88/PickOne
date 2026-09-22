import XCTest

final class ViewingConfirmationInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testWatchedAndOptionalReactionInEnglish() {
        verifyConfirmation(language: "en", reacts: true)
    }

    @MainActor func testWatchedWithoutReactionInSpanishAtAccessibilitySize() {
        verifyConfirmation(
            language: "es",
            reacts: false
        )
    }

    @MainActor
    private func verifyConfirmation(language: String, reacts: Bool) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-home-recovery",
            "-ui-testing-home-recovery-reset",
            "-AppleLanguages",
            "(\(language))",
            "-AppleLocale",
            "\(language)_ES",
        ]
        if language == "es" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        defer {
            app.terminate()
            app.launchArguments = ["-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-cleanup"]
            app.launch()
            app.terminate()
        }
        let pick = app.buttons["home-pick-101"]
        XCTAssertTrue(pick.waitForExistence(timeout: 15))
        for _ in 0 ..< 6 where !pick.isHittable {
            app.swipeUp()
        }
        pick.tap()
        let picked = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", language == "es" ? "Elegida" : "Picked"),
            object: pick
        )
        XCTAssertEqual(XCTWaiter.wait(for: [picked], timeout: 10), .completed)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing-home-recovery-reset" }
        app.launchArguments += ["-ui-testing-confirmation"]
        app.launch()
        let watched = app.buttons["confirmation-watched"]
        XCTAssertTrue(watched.waitForExistence(timeout: 15))
        XCTAssertEqual(watched.label, language == "es" ? "Sí, la vi" : "Yes, I watched it")
        watched.tap()
        let answer = app.buttons[reacts ? "confirmation-reaction-loveIt" : "confirmation-not-now"]
        XCTAssertTrue(answer.waitForExistence(timeout: 15))
        for _ in 0 ..< 5 where !answer.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        answer.tap()
        app.tabBars.buttons["Settings"].tap()
        app.buttons[language == "es" ? "Mis películas" : "My movies"].tap()
        let badge = app.staticTexts["pickone-provenance-101"]
        XCTAssertTrue(badge.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Confirmation provenance \(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons[language == "es" ? "Mis películas" : "My movies"].tap()
        XCTAssertTrue(badge.waitForExistence(timeout: 15), "Provenance survives process recreation")
    }
}
