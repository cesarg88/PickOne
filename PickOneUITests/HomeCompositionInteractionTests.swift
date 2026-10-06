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
        let provider = app.otherElements["home-providers-101"]
        let pick = app.buttons["home-pick-101"]
        XCTAssertTrue(provider.exists)
        XCTAssertTrue(pick.exists)
        XCTAssertTrue(provider.staticTexts["Netflix"].waitForExistence(timeout: 15))
        let providerFrame = provider.frame
        let pickFrame = pick.frame
        XCTAssertLessThan(providerFrame.maxX, pickFrame.minX)
        XCTAssertLessThan(providerFrame.minY, pickFrame.maxY)
        XCTAssertLessThan(pickFrame.minY, providerFrame.maxY)
        XCTAssertTrue(provider.label.contains("Netflix"), "Provider name remains accessible")
        XCTAssertTrue(hero.label.contains("An Extremely Long Movie Title That Wraps Across Several Lines"))
        XCTAssertGreaterThan(hero.frame.height, stretch.frame.height)
        XCTAssertLessThan(hero.frame.height, stretch.frame.height * 2)
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
    func testTwoAndFourProviderLogosStayHorizontalWithTrailingPick() {
        XCUIDevice.shared.orientation = .portrait
        for count in [2, 4] {
            let app = launchComposition(providerCount: count)
            let group = app.otherElements["home-providers-101"]
            let pick = app.buttons["home-pick-101"]
            XCTAssertTrue(group.waitForExistence(timeout: 15))
            XCTAssertTrue(pick.exists)
            let logoIDs = Array([8, 119, 337, 1899].prefix(count))
            let logos = logoIDs.map { group.images["home-provider-\($0)"] }
            XCTAssertTrue(logos.allSatisfy { $0.waitForExistence(timeout: 15) })
            for pair in zip(logos, logos.dropFirst()) {
                XCTAssertLessThan(pair.0.frame.maxX, pair.1.frame.minX)
                XCTAssertEqual(pair.0.frame.midY, pair.1.frame.midY, accuracy: 2)
            }
            XCTAssertLessThan(group.frame.maxX, pick.frame.minX)
            XCTAssertGreaterThanOrEqual(pick.frame.midY, group.frame.minY)
            XCTAssertLessThanOrEqual(pick.frame.midY, group.frame.maxY)
            attachScreenshot(app, name: "Home \(count) horizontal provider logos")
            cleanComposition(app)
        }
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
        XCTAssertEqual(
            poster.label,
            "Open movie details for An Extremely Long Movie Title That Wraps Across Several Lines"
        )
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
    func testReferenceCompositionInEnglishAndSpanish() {
        XCUIDevice.shared.orientation = .portrait
        for (language, locale, title) in [
            ("en", "en_US", "Arrival"),
            ("es", "es_ES", "La llegada"),
        ] {
            let app = launchComposition(
                backdropArgument: "-ui-testing-home-dark-backdrop",
                providerCount: 2,
                referenceCopy: true,
                language: language,
                locale: locale
            )
            let hero = app.buttons["home-recommendation-101"]
            XCTAssertTrue(hero.waitForExistence(timeout: 15))
            XCTAssertTrue(hero.label.contains(title))
            let providers = app.otherElements["home-providers-101"]
            let pick = app.buttons["home-pick-101"]
            XCTAssertTrue(providers.exists)
            XCTAssertTrue(pick.exists)
            XCTAssertLessThan(providers.frame.maxX, pick.frame.minX)
            XCTAssertGreaterThanOrEqual(pick.frame.midY, providers.frame.minY)
            XCTAssertLessThanOrEqual(pick.frame.midY, providers.frame.maxY)
            attachScreenshot(app, name: "Home reference \(language) dark backdrop")
            cleanComposition(app)
        }
    }

    @MainActor
    func testWideIPadLandscapePlacesHeroBesideAlternatives() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launchComposition(
            backdropArgument: "-ui-testing-home-dark-backdrop",
            providerCount: 4,
            referenceCopy: true,
            language: "es",
            locale: "es_ES"
        )
        defer { cleanComposition(app) }

        let hero = app.buttons["home-recommendation-101"]
        let stretch = app.buttons["home-recommendation-202"]
        let discovery = app.buttons["home-recommendation-303"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(stretch.exists)
        XCTAssertTrue(discovery.exists)
        XCTAssertLessThan(hero.frame.maxX, stretch.frame.minX)
        XCTAssertLessThanOrEqual(stretch.frame.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(discovery.frame.maxX, app.frame.maxX)
        XCTAssertTrue(stretch.label.contains("Puñales por la espalda"))
        XCTAssertTrue(discovery.label.contains("Ex Machina"))
        let stretchPick = app.buttons["home-pick-202"]
        let discoveryPick = app.buttons["home-pick-303"]
        XCTAssertTrue(stretchPick.exists)
        XCTAssertTrue(discoveryPick.exists)
        XCTAssertLessThanOrEqual(stretchPick.frame.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(discoveryPick.frame.maxX, app.frame.maxX)
        XCTAssertLessThan(stretch.frame.maxY, discovery.frame.minY)
        attachScreenshot(app, name: "Home reference es iPad landscape")
    }

    @MainActor
    func testIPadPortraitKeepsReferenceCardsReadable() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        XCUIDevice.shared.orientation = .portrait
        let app = launchComposition(
            backdropArgument: "-ui-testing-home-dark-backdrop",
            providerCount: 4,
            referenceCopy: true
        )
        defer { cleanComposition(app) }

        let hero = app.buttons["home-recommendation-101"]
        let stretch = app.buttons["home-recommendation-202"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(stretch.exists)
        XCTAssertLessThan(hero.frame.maxY, stretch.frame.minY)
        XCTAssertTrue(hero.label.contains("Arrival"))
        attachScreenshot(app, name: "Home reference en iPad portrait")
    }

    @MainActor
    private func launchComposition(
        maximumDynamicType: Bool = false,
        brightPoster: Bool = false,
        backdropArgument: String? = nil,
        twoCards: Bool = false,
        providerCount: Int = 1,
        referenceCopy: Bool = false,
        language: String = "en",
        locale: String = "en_US"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-testing-home-recovery", "-ui-testing-home-recovery-reset",
            "-ui-testing-home-composition", "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
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
        if providerCount == 2 {
            app.launchArguments.append("-ui-testing-home-two-providers")
        } else if providerCount == 4 {
            app.launchArguments.append("-ui-testing-home-four-providers")
        }
        if referenceCopy {
            app.launchArguments.append("-ui-testing-home-reference-copy")
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
