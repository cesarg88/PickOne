import XCTest

final class PilotInsightsInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testEnglishCopyAndAccessibleControls() {
        verifyCopyAndAccessibility(language: "en")
    }

    @MainActor func testSpanishCopyAndAccessibleControlsAtAccessibilityXXXL() {
        verifyCopyAndAccessibility(language: "es")
    }

    @MainActor func testDeletionConfirmsAndRemovesCompletedMeasurementAfterRelaunch() {
        let app = launchFixture(language: "en")
        defer { cleanUp(app) }
        let pick = app.buttons["home-pick-101"]
        XCTAssertTrue(pick.isHittable)
        pick.tap()
        let picked = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Picked: Tonight's Movie"),
            object: pick
        )
        XCTAssertEqual(XCTWaiter.wait(for: [picked], timeout: 10), .completed)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing-home-recovery-reset" }
        app.launchArguments.append("-ui-testing-confirmation")
        app.launch()
        let notWatched = app.buttons["confirmation-not-watched"]
        XCTAssertTrue(notWatched.waitForExistence(timeout: 15))
        notWatched.tap()
        XCTAssertTrue(notWatched.waitForNonExistence(timeout: 5))
        openInsights(app)
        assertReportCopy("Not watched after all, 1", in: app)
        let delete = app.buttons["pilot-insights-delete"]
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        // SwiftUI exposes both the wrapper and the nested button for one dialog action.
        let confirm = app.sheets.buttons.matching(identifier: "pilot-insights-confirm-delete").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "Delete measurement")
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        assertReportCopy("Not watched after all, 0", in: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home-pick-101"].waitForExistence(timeout: 15))
        openInsights(app)
        assertReportCopy("Not watched after all, 0", in: app)
        XCTAssertTrue(app.buttons["pilot-insights-delete"].isHittable)
    }

    @MainActor private func verifyCopyAndAccessibility(language: String) {
        let app = launchFixture(language: language)
        defer { cleanUp(app) }
        openInsights(app)
        XCTAssertEqual(
            app.buttons["pilot-insights-export"].label,
            language == "es" ? "Exportar medición local" : "Export local measurement"
        )
        XCTAssertEqual(
            app.buttons["pilot-insights-delete"].label,
            language == "es" ? "Eliminar medición" : "Delete measurement"
        )
        XCTAssertTrue(app.buttons["pilot-insights-export"].isEnabled)
        XCTAssertTrue(app.buttons["pilot-insights-export"].isHittable)
        XCTAssertTrue(app.buttons["pilot-insights-delete"].isEnabled)
        XCTAssertTrue(app.buttons["pilot-insights-delete"].isHittable)
        assertReportCopy(language == "es" ? "Sesiones de recomendaciones" : "Recommendation sessions", in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pilot insights copy and accessibility \(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let delete = app.buttons["pilot-insights-delete"]
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        let confirm = app.sheets.buttons.matching(identifier: "pilot-insights-confirm-delete").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, language == "es" ? "Eliminar medición" : "Delete measurement")
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(confirm.isHittable)
    }

    @MainActor private func launchFixture(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-reset",
            "-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_ES",
        ]
        if language == "es" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["home-pick-101"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func openInsights(_ app: XCUIApplication) {
        app.tabBars.buttons.containing(.image, identifier: "gearshape.fill").firstMatch.tap()
        let link = app.buttons["pilot-insights-link"]
        for _ in 0 ..< 5 where !link.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(link.isHittable)
        let spanish = app.launchArguments.contains("(es)")
        XCTAssertEqual(link.label, spanish ? "Datos del piloto" : "Pilot insights")
        link.tap()
        XCTAssertTrue(app.collectionViews["pilot-insights-report"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pilot-insights-export"].waitForExistence(timeout: 5))
    }

    @MainActor private func assertReportCopy(_ copy: String, in app: XCUIApplication) {
        let report = app.collectionViews["pilot-insights-report"]
        let text = report.staticTexts[copy]
        // This query checks the displayed metric/copy; it never selects an action by its title.
        for _ in 0 ..< 5 where !text.exists {
            report.swipeUp()
        }
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Expected report copy: \(copy)\n\(app.debugDescription)")
    }

    @MainActor private func cleanUp(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-cleanup"]
        app.launch()
        app.terminate()
    }
}
