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

    /// Sets the yellow tolerance. Placeholder: no clamping yet (B-13).
    func setYellowTolerance(_ seconds: Int) {
        settings.yellowTolerance = seconds
    }

    /// Sets the red tolerance. Placeholder: no clamping yet (B-13).
    func setRedTolerance(_ seconds: Int) {
        settings.redTolerance = seconds
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
