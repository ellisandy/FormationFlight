import Foundation
import Testing
@testable import Formation_Flight

@Suite("Safety Disclaimer Tests")
struct SafetyDisclaimerTests {

    /// An isolated `UserDefaults` suite that is empty on entry and removed on exit.
    private func makeIsolatedDefaults(_ suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("A fresh store has not been acknowledged")
    func testFreshStoreIsNotAcknowledged() throws {
        let suiteName = "SafetyDisclaimerTests.testFreshStoreIsNotAcknowledged"
        let defaults = try makeIsolatedDefaults(suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SafetyDisclaimerStore(defaults: defaults)
        #expect(store.hasAcknowledged == false)
        #expect(defaults.object(forKey: SafetyDisclaimerStore.acknowledgedKey) == nil)
    }

    @Test("acknowledge() persists true under the acknowledged key")
    func testAcknowledgePersists() throws {
        let suiteName = "SafetyDisclaimerTests.testAcknowledgePersists"
        let defaults = try makeIsolatedDefaults(suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SafetyDisclaimerStore(defaults: defaults)
        store.acknowledge()

        #expect(store.hasAcknowledged == true)
        #expect(defaults.object(forKey: SafetyDisclaimerStore.acknowledgedKey) != nil)
        #expect(defaults.bool(forKey: "hasAcknowledgedSafetyDisclaimer") == true)

        // A second store over the same defaults sees the acknowledgement too.
        #expect(SafetyDisclaimerStore(defaults: defaults).hasAcknowledged == true)
    }

    @Test("reset() removes the key so the disclaimer shows again")
    func testResetClearsAcknowledgement() throws {
        let suiteName = "SafetyDisclaimerTests.testResetClearsAcknowledgement"
        let defaults = try makeIsolatedDefaults(suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SafetyDisclaimerStore(defaults: defaults)
        store.acknowledge()
        #expect(store.hasAcknowledged == true)

        store.reset()
        #expect(store.hasAcknowledged == false)
        #expect(defaults.object(forKey: SafetyDisclaimerStore.acknowledgedKey) == nil)
    }

    @Test("The disclaimer copy is non-empty")
    func testCopyIsNonEmpty() {
        #expect(!SafetyDisclaimer.title.isEmpty)
        #expect(!SafetyDisclaimer.acknowledgeButtonTitle.isEmpty)
        #expect(!SafetyDisclaimer.settingsFooter.isEmpty)
        #expect(SafetyDisclaimer.paragraphs.count == 3)
        #expect(SafetyDisclaimer.paragraphs.allSatisfy { !$0.isEmpty })
    }
}
