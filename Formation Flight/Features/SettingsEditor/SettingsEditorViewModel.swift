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

    // MARK: - Speed advisory threshold (F-01)

    /// Stepper range for the speed advisory threshold in the pilot's speed unit: the stored
    /// 5 – 30 kt range converted and rounded to whole units.
    var speedThresholdRange: ClosedRange<Int> {
        let knots = CalloutSettings.speedThresholdRangeKnots
        return Self.displayValue(knots: knots.lowerBound, unit: settings.speedUnit)...Self.displayValue(knots: knots.upperBound, unit: settings.speedUnit)
    }

    /// The speed advisory threshold in the pilot's speed unit, whole units.
    var speedThresholdDisplay: Int {
        Self.displayValue(knots: settings.callouts.speedThresholdKnots, unit: settings.speedUnit)
    }

    /// Sets the threshold from a value in the pilot's speed unit. Stored in knots so it keeps
    /// its meaning across unit changes; a whole display value always reads back unchanged.
    func setSpeedThreshold(display value: Int) {
        let clamped = min(max(value, speedThresholdRange.lowerBound), speedThresholdRange.upperBound)
        let knots = Measurement(value: Double(clamped), unit: Self.unitSpeed(settings.speedUnit)).converted(to: .knots).value
        let range = CalloutSettings.speedThresholdRangeKnots
        settings.callouts.speedThresholdKnots = min(max(knots, range.lowerBound), range.upperBound)
    }

    private static func displayValue(knots: Double, unit: Settings.SpeedUnit) -> Int {
        Int(Measurement(value: knots, unit: UnitSpeed.knots).converted(to: unitSpeed(unit)).value.rounded())
    }

    private static func unitSpeed(_ unit: Settings.SpeedUnit) -> UnitSpeed {
        switch unit {
        case .kts: .knots
        case .mph: .milesPerHour
        case .kph: .kilometersPerHour
        }
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
