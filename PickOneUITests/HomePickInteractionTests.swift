import XCTest

final class HomePickInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPickAndCancelInEnglish() {
        verifyPick(language: "en", label: "Pick Tonight's Movie", pickedLabel: "Picked: Tonight's Movie")
    }

    @MainActor
    func testPickAndCancelInSpanishAtAccessibilitySize() {
        verifyPick(language: "es", label: "Elegir Tonight's Movie", pickedLabel: "Elegida: Tonight's Movie")
    }

    @MainActor
    func testFailedCancellationShowsOnlyOneCardRetry() {
        verifyPick(
            language: "en",
            label: "Pick Tonight's Movie",
            pickedLabel: "Picked: Tonight's Movie",
            failsCancellation: true
        )
    }

    @MainActor
    private func verifyPick(language: String, label: String, pickedLabel: String, failsCancellation: Bool = false) {
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
        XCTAssertEqual(pick.label, label)
        pick.tap()
        let picked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", pickedLabel), object: pick)
        XCTAssertEqual(XCTWaiter.wait(for: [picked], timeout: 15), .completed)
        XCTAssertEqual(pick.label, pickedLabel)
        XCTAssertTrue(app.buttons["home-recommendation-101"].exists, "Pick must preserve the recommendation")
        let notice = app.staticTexts[language == "es" ? "Tienes una película elegida" : "You have a Pick"]
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
        pick.tap()
        if failsCancellation {
            verifyFailedCancellation(app: app, pick: pick, pickedLabel: pickedLabel, notice: notice)
        }
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: pick)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 15), .completed)
        XCTAssertEqual(pick.label, label)
    }

    @MainActor
    private func verifyFailedCancellation(
        app: XCUIApplication, pick: XCUIElement, pickedLabel: String, notice: XCUIElement
    ) {
        let retry = app.buttons["home-pick-retry-101"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        XCTAssertEqual(pick.label, pickedLabel, "Failed cancellation must preserve the committed choice")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Try again")).count, 1)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(
                format: "label == %@",
                "Your choice couldn't be saved. Please try again."
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
