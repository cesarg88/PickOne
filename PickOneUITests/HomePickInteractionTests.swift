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
    private func verifyPick(language: String, label: String, pickedLabel: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-reset",
            "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_ES",
        ]
        if language == "es" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
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
        XCTAssertTrue(app.buttons["home-cancel-pick"].waitForExistence(timeout: 15))
        XCTAssertEqual(pick.label, pickedLabel)
        XCTAssertTrue(app.buttons["home-recommendation-101"].exists, "Pick must preserve the recommendation")
        let cancel = app.buttons["home-cancel-pick"]
        if !cancel.isHittable { app.swipeDown() }
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 15))
        XCTAssertEqual(pick.label, label)
    }
}
