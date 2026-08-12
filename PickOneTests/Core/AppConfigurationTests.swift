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
}
