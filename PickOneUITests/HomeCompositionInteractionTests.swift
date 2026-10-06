import XCTest

final class HomeCompositionInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPortraitKeepsHeroAndOrderedAlternatives() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchComposition()
        defer { cleanComposition(app) }

        let hero = app.buttons["home-recommendation-101"]
        let stretch = app.buttons["home-recommendation-202"]
        let discovery = app.buttons["home-recommendation-303"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(stretch.exists)
        XCTAssertTrue(discovery.exists)
        XCTAssertLessThan(hero.frame.maxY, stretch.frame.minY)
        XCTAssertLessThan(stretch.frame.maxY, discovery.frame.minY)
        XCTAssertTrue(app.staticTexts["Two other paths."].exists)
        XCTAssertTrue(hero.label.contains("Netflix"), "Provider name remains readable without a logo")
        attachScreenshot(app, name: "Home composition portrait")
    }

    @MainActor
    func testOneAlternativeUsesSingularHeading() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchComposition(twoCards: true)
        defer { cleanComposition(app) }

        XCTAssertTrue(app.buttons["home-recommendation-202"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Another path."].exists)
        XCTAssertFalse(app.staticTexts["Two other paths."].exists)
        XCTAssertFalse(app.buttons["home-recommendation-303"].exists)
    }

    @MainActor
    func testMaximumDynamicTypeKeepsLastActionsReachable() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchComposition(maximumDynamicType: true)
        defer { cleanComposition(app) }

        let lastPick = app.buttons["home-pick-303"]
        let lastMenu = app.buttons["home-feedback-menu-303"]
        XCTAssertTrue(lastPick.waitForExistence(timeout: 15))
        for _ in 0 ..< 12 where !lastMenu.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(lastMenu.isHittable)
        for _ in 0 ..< 12 where !lastPick.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(lastPick.isHittable)
        let refresh = app.buttons["Give me three more"]
        for _ in 0 ..< 12 where !refresh.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(refresh.isHittable)
        attachScreenshot(app, name: "Home composition maximum text")
    }

    @MainActor
    func testBrightPosterOpensDetailWithoutCoveringFeedback() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchComposition(brightPoster: true)
        defer { cleanComposition(app) }

        let poster = app.buttons["home-poster-link-101"]
        let menu = app.buttons["home-feedback-menu-101"]
        XCTAssertTrue(poster.waitForExistence(timeout: 15))
        XCTAssertTrue(menu.exists)
        XCTAssertGreaterThanOrEqual(menu.frame.minY, poster.frame.maxY)
        attachScreenshot(app, name: "Home bright poster fallback")
        poster.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testBrightBackdropContrastEvidence() {
        verifyBackdrop(
            argument: "-ui-testing-home-bright-backdrop",
            screenshotName: "Home bright backdrop scrim"
        )
    }

    @MainActor
    func testDarkBackdropContrastEvidence() {
        verifyBackdrop(
            argument: "-ui-testing-home-dark-backdrop",
            screenshotName: "Home dark backdrop scrim"
        )
    }

    @MainActor
    func testWideIPadLandscapePlacesHeroBesideAlternatives() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launchComposition()
        defer { cleanComposition(app) }

        let hero = app.buttons["home-recommendation-101"]
        let stretch = app.buttons["home-recommendation-202"]
        let discovery = app.buttons["home-recommendation-303"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(stretch.exists)
        XCTAssertTrue(discovery.exists)
        XCTAssertLessThan(hero.frame.maxX, stretch.frame.minX)
        XCTAssertLessThan(stretch.frame.maxY, discovery.frame.minY)
        attachScreenshot(app, name: "Home composition iPad landscape")
    }

    @MainActor
    private func launchComposition(
        maximumDynamicType: Bool = false,
        brightPoster: Bool = false,
        backdropArgument: String? = nil,
        twoCards: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-reset",
            "-ui-testing-home-composition", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        if maximumDynamicType {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        if brightPoster {
            app.launchArguments.append("-ui-testing-home-poster")
        }
        if let backdropArgument {
            app.launchArguments.append(backdropArgument)
        }
        if twoCards {
            app.launchArguments.append("-ui-testing-home-two-cards")
        }
        app.launch()
        return app
    }

    @MainActor
    private func verifyBackdrop(argument: String, screenshotName: String) {
        XCUIDevice.shared.orientation = .portrait
        let app = launchComposition(backdropArgument: argument)
        defer { cleanComposition(app) }

        let hero = app.buttons["home-recommendation-101"]
        let menu = app.buttons["home-feedback-menu-101"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(menu.exists)
        XCTAssertFalse(app.buttons["home-poster-link-101"].exists)
        attachScreenshot(app, name: screenshotName)
    }

    @MainActor
    private func cleanComposition(_ app: XCUIApplication) {
        app.terminate()
        let cleanup = XCUIApplication()
        cleanup.launchArguments = ["-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-cleanup"]
        cleanup.launch()
        cleanup.terminate()
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
