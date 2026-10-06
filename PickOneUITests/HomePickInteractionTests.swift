import XCTest

final class HomePickInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPickAndCancelInEnglish() {
        verifyPick(language: "en", pickPrefix: "Pick ", pickedPrefix: "Picked: ")
    }

    @MainActor
    func testPickAndCancelInSpanishAtAccessibilitySize() {
        verifyPick(language: "es", pickPrefix: "Elegir ", pickedPrefix: "Elegida: ")
    }

    @MainActor
    func testFailedCancellationShowsOnlyOneCardRetry() {
        verifyPick(
            language: "en",
            pickPrefix: "Pick ",
            pickedPrefix: "Picked: ",
            failsCancellation: true
        )
    }

    @MainActor
    func testNoticesCoexistAtMaximumTextWithReducedMotionAndTransparency() {
        let app = launchHomeForTransitionEvidence(extraArguments: [
            "-ui-testing-hold-home-pick-notice",
            "-ui-testing-home-reduced-accessibility",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        defer { cleanHomeScenario(app) }
        let pick = app.buttons["home-pick-101"]
        let menu = app.buttons["home-feedback-menu-101"]
        let status = app.descendants(matching: .any)["home-decision-status"]
        XCTAssertTrue(pick.waitForExistence(timeout: 15))
        XCTAssertTrue(menu.exists)
        XCTAssertGreaterThanOrEqual(pick.frame.height, 44)
        XCTAssertGreaterThanOrEqual(menu.frame.height, 44)
        XCTAssertTrue(status.exists)
        let reservedHeight = status.frame.height

        pick.tap()
        XCTAssertTrue(app.staticTexts["You picked Tonight's Movie."].waitForExistence(timeout: 15))
        menu.tap()
        app.buttons["Not interested"].tap()
        XCTAssertTrue(app.buttons["home-recommendation-202"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Recommendations updated."].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["You picked Tonight's Movie."].exists)
        XCTAssertEqual(status.frame.height, reservedHeight, accuracy: 1)
        XCTAssertTrue(app.staticTexts["You picked Tonight's Movie."].isHittable)
        let statusStart = status.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let statusEnd = status.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        statusStart.press(forDuration: 0.05, thenDragTo: statusEnd)
        XCTAssertTrue(app.buttons["home-recommendation-202"].exists, "Scrolling the notice must not switch tabs")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home simultaneous notices, XXXL, reduced motion and transparency"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let updated = app.staticTexts["Recommendations updated."]
        XCTAssertTrue(updated.isHittable, "Status: \(status.frame), update: \(updated.frame)")
        XCTAssertLessThan(updated.frame.maxY, app.tabBars.firstMatch.frame.minY)
    }

    @MainActor
    func testFeedbackReplacementRestoresAccessibilityFocusToRoleSlot() {
        let app = launchHomeForTransitionEvidence(extraArguments: ["-ui-testing-home-reduced-accessibility"])
        defer { cleanHomeScenario(app) }
        let menu = app.buttons["home-feedback-menu-101"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
        app.buttons["Already watched"].tap()
        XCTAssertTrue(app.buttons["home-recommendation-202"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["home-recommendation-101"].exists)
        XCTAssertTrue(app.otherElements["home-focus-target-slot-safe"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchHomeForTransitionEvidence(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-reset",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func cleanHomeScenario(_ app: XCUIApplication) {
        app.terminate()
        let cleanup = XCUIApplication()
        cleanup.launchArguments = ["-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-cleanup"]
        cleanup.launch()
        cleanup.terminate()
    }

    @MainActor
    private func verifyPick(
        language: String,
        pickPrefix: String,
        pickedPrefix: String,
        failsCancellation: Bool = false
    ) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-reset",
            "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_ES",
        ]
        if language == "es" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        if failsCancellation { app.launchArguments += ["-ui-testing-pick-cancel-fails-once"] }
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments = ["-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        let pick = app.buttons["home-pick-101"]
        XCTAssertTrue(pick.waitForExistence(timeout: 15))
        for _ in 0 ..< 6 where !pick.isHittable {
            app.swipeUp()
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home Pick \(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(pick.isHittable)
        XCTAssertGreaterThanOrEqual(pick.frame.width, 44)
        XCTAssertGreaterThanOrEqual(pick.frame.height, 44)
        XCTAssertTrue(pick.label.hasPrefix(pickPrefix))
        let movieTitle = String(pick.label.dropFirst(pickPrefix.count))
        XCTAssertFalse(movieTitle.isEmpty)
        let label = pickPrefix + movieTitle
        let pickedLabel = pickedPrefix + movieTitle
        let originalFrame = pick.frame
        pick.tap()
        let picked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", pickedLabel), object: pick)
        XCTAssertEqual(XCTWaiter.wait(for: [picked], timeout: 15), .completed)
        XCTAssertEqual(pick.label, pickedLabel)
        XCTAssertEqual(
            pick.frame.minY,
            originalFrame.minY,
            accuracy: 1,
            "The success notice must not move the selected control"
        )
        XCTAssertTrue(app.buttons["home-recommendation-101"].exists, "Pick must preserve the recommendation")
        let notice = app.staticTexts[language == "es"
            ? "Has elegido \(movieTitle)." : "You picked \(movieTitle)."]
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "Success feedback names the committed movie")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 8), "Pick feedback must dismiss automatically")
        XCTAssertEqual(pick.label, pickedLabel, "Dismissing feedback must preserve the choice")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing-home-recovery-reset" }
        app.launch()
        XCTAssertTrue(pick.waitForExistence(timeout: 15))
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", pickedLabel),
            object: pick
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [restored], timeout: 15),
            .completed,
            "Relaunch must restore the selected card"
        )
        XCTAssertFalse(notice.exists, "Relaunch must not replay the success notice")
        XCTAssertFalse(app.buttons["home-cancel-pick"].exists, "Cancellation belongs on the selected card")
        for _ in 0 ..< 6 where !pick.isHittable {
            app.swipeUp()
        }
        let beforeCancellationFrame = pick.frame
        pick.tap()
        if failsCancellation {
            verifyFailedCancellation(app: app, pick: pick, pickedLabel: pickedLabel, notice: notice)
        }
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: pick)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 15), .completed)
        XCTAssertEqual(pick.label, label)
        XCTAssertEqual(
            pick.frame.minY,
            beforeCancellationFrame.minY,
            accuracy: 1,
            "Durable cancellation must not shift the card"
        )
        let cancellationNotice = app.staticTexts[
            language == "es" ? "Elección cancelada." : "Choice cancelled."
        ]
        XCTAssertTrue(
            cancellationNotice.waitForExistence(timeout: 3),
            "Durable cancellation must announce its result"
        )
    }

    @MainActor
    private func verifyFailedCancellation(
        app: XCUIApplication, pick: XCUIElement, pickedLabel: String, notice: XCUIElement
    ) {
        let retry = app.buttons["home-pick-retry-101"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        XCTAssertEqual(pick.label, pickedLabel, "Failed cancellation must preserve the committed choice")
        XCTAssertTrue(retry.label.hasPrefix("Retry cancelling your choice of "))
        XCTAssertEqual(app.buttons.matching(identifier: "home-pick-retry-101").count, 1)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(
                format: "label == %@",
                "Your choice couldn't be cancelled. Please try again."
            )).count,
            1
        )
        XCTAssertFalse(notice.exists)
        for _ in 0 ..< 6 where !retry.isHittable {
            app.swipeUp()
        }
        retry.tap()
    }
}
