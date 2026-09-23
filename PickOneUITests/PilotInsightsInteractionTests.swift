import XCTest

final class PilotInsightsInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testEnglishInsightsExportAndDeletion() {
        verifyInsights(language: "en")
    }

    @MainActor func testSpanishInsightsAtAccessibilitySize() {
        verifyInsights(language: "es")
    }

    @MainActor private func verifyInsights(language: String) {
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
            app.launchArguments = ["-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-cleanup"]
            app.launch()
            app.terminate()
        }
        XCTAssertTrue(app.buttons["home-pick-101"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        let title = language == "es" ? "Datos del piloto" : "Pilot insights"
        let link = app.buttons["pilot-insights-link"]
        for _ in 0 ..< 5 where !link.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        XCTAssertEqual(link.label, title)
        link.tap()
        let sessions = app.staticTexts[language == "es" ? "Sesiones de recomendaciones" : "Recommendation sessions"]
        let report = app.collectionViews["pilot-insights-report"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        for _ in 0 ..< 5 where !sessions.exists {
            report.swipeUp()
        }
        XCTAssertTrue(sessions.waitForExistence(timeout: 10), app.debugDescription)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pilot insights \(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let export = app.buttons["pilot-insights-export"]
        XCTAssertEqual(export.label, language == "es" ? "Exportar medición local" : "Export local measurement")
        XCTAssertTrue(export.isHittable)
        export.tap()
        let deleteTitle = language == "es" ? "Eliminar medición" : "Delete measurement"
        let deleteButton = app.buttons["pilot-insights-delete"]
        XCTAssertEqual(deleteButton.label, deleteTitle)
        let save = app.buttons.matching(NSPredicate(format: "label == 'Save' OR label == 'Guardar'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertFalse(deleteButton.isHittable)
        save.tap()
        let replace = app.buttons.matching(NSPredicate(format: "label == 'Replace' OR label == 'Reemplazar'"))
            .firstMatch
        if replace.waitForExistence(timeout: 2) { replace.tap() }
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        // Save can disappear before the modal closes; wait for our own action to be interactive.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: deleteButton)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, app.debugDescription)
        let returnedScreen = XCTAttachment(screenshot: app.screenshot())
        returnedScreen.name = "After Files export \(language)"
        returnedScreen.lifetime = .keepAlways
        add(returnedScreen)
        XCTAssertTrue(deleteButton.isHittable, app.debugDescription)
        deleteButton.tap()
        // SwiftUI exposes the dialog action through both its wrapper and nested button.
        let dialog = app.sheets.buttons.matching(identifier: "pilot-insights-confirm-delete").firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        XCTAssertEqual(dialog.label, deleteTitle)
        XCTAssertTrue(dialog.isHittable)
        dialog.tap()
        let failure = language == "es"
            ? "No se pudo completar la acción. Inténtalo de nuevo."
            : "The action could not be completed. Please try again."
        XCTAssertFalse(app.staticTexts[failure].exists)
        app.tabBars.buttons[language == "es" ? "Inicio" : "Home"].tap()
        XCTAssertTrue(app.buttons["home-pick-101"].waitForExistence(timeout: 10))
    }
}
