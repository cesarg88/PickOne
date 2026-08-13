import Foundation
@testable import PickOne
import Testing

@Suite("Decision Set data store", .serialized)
struct DecisionSetDataStoreTests {
    @Test("active envelope and diagnostic quarantine persist independently")
    func independentStorage() throws {
        let suiteName = "PickOneTests.DecisionSetDataStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)
        let store = UserDefaultsDecisionSetDataStore(suiteName: suiteName)
        let active = Data("active-envelope".utf8)
        let diagnostic = Data("original-corrupt-envelope".utf8)

        try store.replaceActive(with: active)
        try store.replaceQuarantine(with: diagnostic)

        let relaunched = UserDefaultsDecisionSetDataStore(suiteName: suiteName)
        #expect(try relaunched.readActive() == active)
        #expect(try relaunched.readQuarantine() == diagnostic)

        try relaunched.replaceActive(with: Data("replacement".utf8))
        #expect(try relaunched.readQuarantine() == diagnostic)
    }
}
