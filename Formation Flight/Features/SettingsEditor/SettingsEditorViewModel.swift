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
