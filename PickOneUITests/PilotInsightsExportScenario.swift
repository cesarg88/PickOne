import XCTest

/// Simulator fixture inspection is read-only. Folder/file creation goes through the real Files picker.
@MainActor
struct PilotInsightsExportScenario {
    func export(from app: XCUIApplication) throws {
        let identity = UUID().uuidString
        let folderName = "PickOne-UIExport-\(identity)"
        let fileName = "measurement-\(identity)"
        app.buttons["pilot-insights-export"].tap()
        let navigation = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 10))
        let localLocation = app.cells["DOC.sidebar.item.On My iPhone"]
        // A previous invocation may have left Files inside its own folder. Always choose the local root.
        for _ in 0 ..< 8 where !localLocation.isHittable {
            let back = navigation.buttons["BackButton"]
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
        }
        XCTAssertTrue(localLocation.isHittable)
        localLocation.tap()
        // Resolve the provider only after Files has initialized the selected local location.
        let localStorage = try simulatorLocalStorage()
        let destination = localStorage.appendingPathComponent(folderName, isDirectory: true)
        let artifact = destination.appendingPathComponent(fileName).appendingPathExtension("json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        createFolder(folderName, in: app, navigation: navigation)
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 5))
        replaceText(in: filename, with: fileName)
        filename.typeText("\n")
        // Native Save has no explicit identifier; it is the trailing navigation-bar action.
        let save = try XCTUnwrap(navigation.buttons.allElementsBoundByIndex.max {
            $0.frame.minX < $1.frame.minX
        })
        XCTAssertEqual(save.label, "Save")
        XCTAssertTrue(save.isHittable)
        save.tap()

        let export = app.buttons["pilot-insights-export"]
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: export)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 10), .completed, app.debugDescription)
        let committed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Self.isCompleteReport(at: artifact)
        }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [committed], timeout: 10),
            .completed,
            "Expected a complete JSON report at the unique Files destination: \(artifact.path)"
        )
        let data = try Data(contentsOf: artifact)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(report.keys), ["schemaVersion", "exportedAt", "summary", "records"])
        XCTAssertEqual(report["schemaVersion"] as? Int, 1)
        let summary = try XCTUnwrap(report["summary"] as? [String: Any])
        XCTAssertEqual(summary["sessions"] as? Int, 1)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: destination.path),
            [artifact.lastPathComponent]
        )
        XCTContext.runActivity(named: "Isolated native export \(folderName)") { activity in
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = artifact.lastPathComponent
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
        XCTAssertTrue(export.isHittable)
        XCTAssertTrue(app.buttons["pilot-insights-delete"].isHittable)
    }

    private func createFolder(_ name: String, in app: XCUIApplication, navigation: XCUIElement) {
        let overflow = navigation.buttons["OverflowBarButtonItem"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        overflow.tap()
        let create = app.buttons.containing(.image, identifier: "folder.badge.plus").firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertEqual(create.label, "New Folder")
        create.tap()
        let rename = app.textViews["DOC.inlineRenameField"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        replaceText(in: rename, with: name)
        rename.typeText("\n")
        XCTAssertTrue(rename.waitForNonExistence(timeout: 5))
        // Files enters a newly created folder when inline renaming finishes.
        let destination = app.otherElements[
            "DOC.browsingRoot Source: com.apple.FileProvider.LocalStorage, Title: \(name)"
        ]
        XCTAssertTrue(destination.waitForExistence(timeout: 5), app.debugDescription)
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        let current = (field.value as? String) ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }

    private nonisolated static func isCompleteReport(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let report = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return false }
        return report["schemaVersion"] as? Int == 1 && report["summary"] is [String: Any]
            && report["records"] is [String: Any]
    }

    private func simulatorLocalStorage() throws -> URL {
        let root = try XCTUnwrap(
            ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"],
            "This native export artifact test requires the repository's iOS Simulator destination"
        )
        let groups = URL(fileURLWithPath: root).appendingPathComponent("Containers/Shared/AppGroup", isDirectory: true)
        let containers = try FileManager.default.contentsOfDirectory(at: groups, includingPropertiesForKeys: nil)
        for container in containers {
            let metadata = container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let data = try? Data(contentsOf: metadata),
                  let values = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
                  values["MCMMetadataIdentifier"] as? String == "group.com.apple.FileProvider.LocalStorage"
            else { continue }
            return container.appendingPathComponent("File Provider Storage", isDirectory: true)
        }
        throw NSError(
            domain: "PilotInsightsExportFixture",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Simulator local Files storage is unavailable"]
        )
    }
}
