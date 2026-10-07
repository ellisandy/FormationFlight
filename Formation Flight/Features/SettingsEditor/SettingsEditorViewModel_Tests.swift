import Foundation
import Testing
@testable import Formation_Flight

@Suite("SettingsEditorViewModel")
struct SettingsEditorViewModelTests {
    /// A throwaway `UserDefaults` suite plus the hook that deletes it again.
    ///
    /// `UserDefaults(suiteName:)` writes a real plist under the test host's Library, so every
    /// suite a test creates must be removed afterwards or they accumulate across runs.
    private struct IsolatedDefaults {
        let defaults: UserDefaults
        let suiteName: String

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func makeIsolatedDefaults() throws -> IsolatedDefaults {
        let suiteName = "com.example.FormationFlight.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return IsolatedDefaults(defaults: defaults, suiteName: suiteName)
    }

    // MARK: - Persistence: reset
    @Test("reset() loads from UserDefaults")
    func reset_loadsFromUserDefaults() async throws {
        let isolated = try makeIsolatedDefaults()
        defer { isolated.cleanUp() }
        let defaults = isolated.defaults
        // Prepare persisted settings
        var initial = Settings.empty()
        initial.speedUnit = .mph
        initial.distanceUnit = .km
        initial.save(to: defaults)

        // Start VM with different in-memory settings
        let other = Settings.empty()
        let vm = SettingsEditorViewModel(settings: other)

        vm.reset(userDefaults: defaults)
        #expect(vm.settings.speedUnit == .mph)
        #expect(vm.settings.distanceUnit == .km)
    }

    // MARK: - Persistence: save
    @Test("save() writes to UserDefaults")
    func save_writesToUserDefaults() async throws {
        let isolated = try makeIsolatedDefaults()
        defer { isolated.cleanUp() }
        let defaults = isolated.defaults
        var s = Settings.empty()
        s.speedUnit = .kts
        s.distanceUnit = .nm
        let vm = SettingsEditorViewModel(settings: s)

        vm.save(userDefaults: defaults)

        let loaded = Settings.load(from: defaults)
        #expect(loaded.speedUnit == .kts)
        #expect(loaded.distanceUnit == .nm)
    }

    @Test("save() normalizes yellow > red before persisting")
    func save_normalizesInvertedTolerances() async throws {
        let isolated = try makeIsolatedDefaults()
        defer { isolated.cleanUp() }
        let defaults = isolated.defaults
        var s = Settings.empty()
        s.yellowTolerance = 45
        s.redTolerance = 20
        let vm = SettingsEditorViewModel(settings: s)

        vm.save(userDefaults: defaults)

        // Persisted pair is self-consistent: red raised to yellow.
        let loaded = Settings.load(from: defaults)
        #expect(loaded.yellowTolerance == 45)
        #expect(loaded.redTolerance == 45)
        #expect(loaded.yellowTolerance <= loaded.redTolerance)

        // The editor's in-memory settings reflect what was actually saved.
        #expect(vm.settings.yellowTolerance == 45)
        #expect(vm.settings.redTolerance == 45)
    }

    @Test("save() clamps negative tolerances to 0 before persisting")
    func save_clampsNegativeTolerances() async throws {
        let isolated = try makeIsolatedDefaults()
        defer { isolated.cleanUp() }
        let defaults = isolated.defaults
        var s = Settings.empty()
        s.yellowTolerance = -3
        s.redTolerance = -7
        let vm = SettingsEditorViewModel(settings: s)

        vm.save(userDefaults: defaults)

        let loaded = Settings.load(from: defaults)
        #expect(loaded.yellowTolerance == 0)
        #expect(loaded.redTolerance == 0)
    }

    // MARK: - Factory
    @Test("from(userDefaults:) creates VM with persisted settings")
    func factory_fromUserDefaults() async throws {
        let isolated = try makeIsolatedDefaults()
        defer { isolated.cleanUp() }
        let defaults = isolated.defaults
        var s = Settings.empty()
        s.speedUnit = .kph
        s.distanceUnit = .km
        s.save(to: defaults)

        let vm = SettingsEditorViewModel.from(userDefaults: defaults)
        #expect(vm.settings.speedUnit == .kph)
        #expect(vm.settings.distanceUnit == .km)
    }
}
