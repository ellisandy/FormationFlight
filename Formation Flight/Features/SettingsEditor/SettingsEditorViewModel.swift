import Foundation
import Observation

@Observable
final class SettingsEditorViewModel {
    var settings: Settings

    init(settings: Settings = .empty()) {
        self.settings = settings
    }

    func reset(userDefaults: UserDefaults) {
        // Reload from persistence into `settings`
        let persisted = Settings.load(from: userDefaults)
        self.settings = persisted
    }

    // MARK: - Tolerance steppers (B-13)

    /// Values the tolerance steppers can select, in seconds (0 to 10 minutes).
    static let toleranceRange = 0...600

    /// Sets the yellow tolerance, clamped to `toleranceRange`.
    ///
    /// The `yellow <= red` invariant that `Settings.validated()` enforces on save is applied
    /// live: raising yellow past red drags red up with it, so the pilot sees the pair they
    /// will actually get instead of a silent correction at Save.
    func setYellowTolerance(_ seconds: Int) {
        let yellow = Self.clampTolerance(seconds)
        settings.yellowTolerance = yellow
        if settings.redTolerance < yellow {
            settings.redTolerance = yellow
        }
    }

    /// Sets the red tolerance, clamped to `toleranceRange` and never below yellow.
    func setRedTolerance(_ seconds: Int) {
        settings.redTolerance = max(Self.clampTolerance(seconds), settings.yellowTolerance)
    }

    private static func clampTolerance(_ seconds: Int) -> Int {
        min(max(seconds, toleranceRange.lowerBound), toleranceRange.upperBound)
    }

    func save(userDefaults: UserDefaults) {
        // Normalise the tolerance pair (no negatives, yellow <= red) before persisting,
        // and reflect the normalised values back into the editor.
        settings = settings.validated()
        settings.save(to: userDefaults)
    }
}

extension SettingsEditorViewModel {
    static func from(userDefaults: UserDefaults) -> SettingsEditorViewModel {
        SettingsEditorViewModel(settings: Settings.load(from: userDefaults))
    }
}
