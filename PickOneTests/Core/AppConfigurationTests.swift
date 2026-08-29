import Foundation
@testable import PickOne
import Testing

@Suite("App configuration tests")
struct AppConfigurationTests {
    @Test("the hosted unit-test process is detected")
    func detectsHostedUnitTestProcess() {
        #expect(AppConfiguration.isUnitTesting)
    }

    @Test("unit-test detection depends only on the XCTest configuration")
    func detectsUnitTestConfiguration() {
        #expect(AppConfiguration.detectsUnitTestHost(in: [
            "XCTestConfigurationFilePath": "/tmp/PickOneTests.xctestconfiguration",
        ]))
        #expect(!AppConfiguration.detectsUnitTestHost(in: [:]))
    }

    @Test("calibration catalog accepts only credential-free HTTPS URLs")
    func validatesCalibrationCatalogURL() {
        #expect(
            AppConfiguration.calibrationCatalogURL(
                from: " https://catalog.example.com/es-ES.json "
            ) == URL(string: "https://catalog.example.com/es-ES.json")
        )
        #expect(AppConfiguration.calibrationCatalogURL(from: nil) == nil)
        #expect(AppConfiguration.calibrationCatalogURL(from: "") == nil)
        #expect(
            AppConfiguration.calibrationCatalogURL(
                from: "http://catalog.example.com/es-ES.json"
            ) == nil
        )
        #expect(
            AppConfiguration.calibrationCatalogURL(
                from: "https://user:password@catalog.example.com/es-ES.json"
            ) == nil
        )
    }
}
