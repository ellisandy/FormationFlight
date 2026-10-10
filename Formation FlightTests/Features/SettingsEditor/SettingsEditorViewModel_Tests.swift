import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

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

    // MARK: - Tolerance steppers (B-13)
    //
    // The steppers in SettingsEditorFormView drive these setters so the yellow <= red
    // invariant `Settings.validated()` enforces on save is visible live, not only after Save.

    @Test("setYellowTolerance raising yellow past red drags red up to match")
    func setYellowTolerance_pushesRedUp() {
        var s = Settings.empty()
        s.yellowTolerance = 10
        s.redTolerance = 30
        let vm = SettingsEditorViewModel(settings: s)

        vm.setYellowTolerance(31)

        #expect(vm.settings.yellowTolerance == 31)
        #expect(vm.settings.redTolerance == 31)
    }

    @Test("setYellowTolerance below red leaves red alone")
    func setYellowTolerance_belowRed_leavesRed() {
        var s = Settings.empty()
        s.yellowTolerance = 10
        s.redTolerance = 30
        let vm = SettingsEditorViewModel(settings: s)

        vm.setYellowTolerance(20)

        #expect(vm.settings.yellowTolerance == 20)
        #expect(vm.settings.redTolerance == 30)
    }

    @Test("setRedTolerance never drops red below yellow")
    func setRedTolerance_holdsAtYellow() {
        var s = Settings.empty()
        s.yellowTolerance = 20
        s.redTolerance = 30
        let vm = SettingsEditorViewModel(settings: s)

        vm.setRedTolerance(15)

        #expect(vm.settings.redTolerance == 20)
        #expect(vm.settings.yellowTolerance == 20)
    }

    @Test("tolerance setters clamp to the stepper range")
    func toleranceSetters_clampToRange() {
        let vm = SettingsEditorViewModel(settings: .empty())

        vm.setYellowTolerance(-5)
        #expect(vm.settings.yellowTolerance == SettingsEditorViewModel.toleranceRange.lowerBound)

        vm.setRedTolerance(10_000)
        #expect(vm.settings.redTolerance == SettingsEditorViewModel.toleranceRange.upperBound)

        vm.setYellowTolerance(10_000)
        #expect(vm.settings.yellowTolerance == SettingsEditorViewModel.toleranceRange.upperBound)
        #expect(vm.settings.redTolerance == SettingsEditorViewModel.toleranceRange.upperBound)
    }

    @Test("tolerance range spans 0 to 600 seconds")
    func toleranceRange_isZeroToTenMinutes() {
        #expect(SettingsEditorViewModel.toleranceRange == 0...600)
        #expect(SettingsEditorViewModel.toleranceRange.contains(Settings.defaultYellowTolerance))
        #expect(SettingsEditorViewModel.toleranceRange.contains(Settings.defaultRedTolerance))
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

    // MARK: - Speed advisory threshold (F-01)
    @Test("Threshold range and value follow the speed unit")
    func speedThresholdInDisplayUnit() {
        var settings = Settings.empty()
        settings.speedUnit = .kph
        let vm = SettingsEditorViewModel(settings: settings)
        #expect(vm.speedThresholdRange == 9...56)
        #expect(vm.speedThresholdDisplay == 19)
        vm.settings.speedUnit = .kts
        #expect(vm.speedThresholdRange == 5...30)
        #expect(vm.speedThresholdDisplay == 10)
    }

    @Test("Every whole display value reads back unchanged")
    func speedThresholdRoundTrip() {
        for unit in Settings.SpeedUnit.allCases {
            var settings = Settings.empty()
            settings.speedUnit = unit
            let vm = SettingsEditorViewModel(settings: settings)
            for value in vm.speedThresholdRange {
                vm.setSpeedThreshold(display: value)
                #expect(vm.speedThresholdDisplay == value, "\(unit) \(value)")
            }
        }
    }

    @Test("Out-of-range display values are clamped")
    func speedThresholdClamped() {
        let vm = SettingsEditorViewModel(settings: .empty())
        vm.setSpeedThreshold(display: 100)
        #expect(vm.settings.callouts.speedThresholdKnots == 30)
        vm.setSpeedThreshold(display: 0)
        #expect(vm.settings.callouts.speedThresholdKnots == 5)
    }
}
