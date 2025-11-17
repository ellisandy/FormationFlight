import Foundation

final class SettingsEditorViewModel: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var settings: Settings
    
    init(settings: Settings = .empty()) {
        self.settings = settings
    }
    
    func present() {
        isPresented = true
    }
    
    func dismiss() {
        isPresented = false
    }
    
    func reset(userDefaults: UserDefaults) {
        // Reload from persistence into `settings`
        let persisted = Settings.load(from: userDefaults)
        self.settings = persisted
    }
    
    func save(userDefaults: UserDefaults) {
        settings.save(to: userDefaults)
    }
}

extension SettingsEditorViewModel {
    static func from(userDefaults: UserDefaults) -> SettingsEditorViewModel {
        SettingsEditorViewModel(settings: Settings.load(from: userDefaults))
    }
}
