import Foundation
import Testing
@testable import Formation_Flight

@Suite("SettingsEditorViewModel")
struct SettingsEditorViewModelTests {
    // Helper to create isolated UserDefaults
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "com.example.FormationFlight.tests.\(UUID().uuidString)"
        // Force unwrap is acceptable in tests; if this fails, it's a test environment issue.
        return UserDefaults(suiteName: suiteName)!
    }

    // MARK: - Presentation
    @Test("present() sets isPresented to true")
    func present_setsIsPresented() async throws {
        let vm = SettingsEditorViewModel(settings: .empty())
        #expect(vm.isPresented == false)
        vm.present()
        #expect(vm.isPresented == true)
    }

    @Test("dismiss() sets isPresented to false")
    func dismiss_setsIsPresented() async throws {
        let vm = SettingsEditorViewModel(settings: .empty())
        vm.present()
        #expect(vm.isPresented == true)
        vm.dismiss()
        #expect(vm.isPresented == false)
    }

    // MARK: - Persistence: reset
    @Test("reset() loads from UserDefaults")
    func reset_loadsFromUserDefaults() async throws {
        let defaults = makeIsolatedDefaults()
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
        let defaults = makeIsolatedDefaults()
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
        let defaults = makeIsolatedDefaults()
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
        let defaults = makeIsolatedDefaults()
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
        let defaults = makeIsolatedDefaults()
        var s = Settings.empty()
        s.speedUnit = .kph
        s.distanceUnit = .km
        s.save(to: defaults)

        let vm = SettingsEditorViewModel.from(userDefaults: defaults)
        #expect(vm.settings.speedUnit == .kph)
        #expect(vm.settings.distanceUnit == .km)
    }
}
