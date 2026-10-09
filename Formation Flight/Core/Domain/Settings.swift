import Foundation
import FormationFlightCore

public struct Settings: Codable, Equatable {
    public var speedUnit: SpeedUnit
    public var distanceUnit: DistanceUnit
    public var yellowTolerance: Int
    public var redTolerance: Int
    public var instrumentSettings: [InstrumentSetting]
    /// In-flight banner and voice callouts (F-01).
    public var callouts: CalloutSettings
    
    public func getUnitSpeed() -> UnitSpeed {
        switch speedUnit {
        case .kph:
            return .kilometersPerHour
        case .kts:
            return .knots
        case .mph:
            return .milesPerHour
        }
    }
    
    public func getDistanceUnits() -> UnitLength {
        switch distanceUnit {
        case .km:
            return .kilometers
        case .mi:
            return .miles
        case .nm:
            return .nauticalMiles
        }
    }
    
    /// The display units live in FormationFlightCore so the callout engine, the Live Activity
    /// and the watch can use them; these aliases keep `Settings.SpeedUnit` working at call
    /// sites. Raw values and Codable shape are unchanged, so saved settings still decode.
    public typealias SpeedUnit = FormationFlightCore.SpeedUnit
    public typealias DistanceUnit = FormationFlightCore.DistanceUnit
    
    /// Default ToT drift tolerances, in seconds. A fresh install must not treat every
    /// non-zero delta as red, so these are deliberately non-zero with yellow <= red.
    public static let defaultYellowTolerance = 10
    public static let defaultRedTolerance = 30

    /// The settings a fresh install starts with. Alias for `empty()`.
    public static func defaults() -> Settings {
        return empty()
    }

    public static func empty() -> Settings {
        return Settings(
            speedUnit: .kts,
            distanceUnit: .nm,
            yellowTolerance: defaultYellowTolerance,
            redTolerance: defaultRedTolerance,
            instrumentSettings: [
                InstrumentSetting(type: .currentGroundSpeed, isEnabled: true),
                InstrumentSetting(type: .requiredGroundSpeed, isEnabled: true),
                InstrumentSetting(type: .distance, isEnabled: true),
                InstrumentSetting(type: .bearing, isEnabled: true),
                InstrumentSetting(type: .track, isEnabled: true),
            ],
            callouts: .defaults
        )
    }
    
    /// Returns a copy with the tolerance pair made self-consistent: negative values are
    /// clamped to 0 and, if yellow exceeds red, red is raised to match yellow.
    public func validated() -> Settings {
        var copy = self
        copy.yellowTolerance = max(0, copy.yellowTolerance)
        copy.redTolerance = max(0, copy.redTolerance)
        if copy.yellowTolerance > copy.redTolerance {
            copy.redTolerance = copy.yellowTolerance
        }
        copy.callouts = copy.callouts.validated()
        return copy
    }

    // Explicit CodingKeys to ensure stable Codable synthesis
    private enum CodingKeys: String, CodingKey {
        case speedUnit
        case distanceUnit
        case yellowTolerance
        case redTolerance
        case instrumentSettings
        case callouts
    }
    
    // Explicit init(from:) to avoid any synthesis issues
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.speedUnit = try container.decode(SpeedUnit.self, forKey: .speedUnit)
        self.distanceUnit = try container.decode(DistanceUnit.self, forKey: .distanceUnit)
        self.yellowTolerance = try container.decode(Int.self, forKey: .yellowTolerance)
        self.redTolerance = try container.decode(Int.self, forKey: .redTolerance)
        self.instrumentSettings = try container.decode([InstrumentSetting].self, forKey: .instrumentSettings)
        // Absent in data written before F-01.
        self.callouts = try container.decodeIfPresent(CalloutSettings.self, forKey: .callouts) ?? .defaults
    }
    
    // Explicit encode(to:)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(speedUnit, forKey: .speedUnit)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(yellowTolerance, forKey: .yellowTolerance)
        try container.encode(redTolerance, forKey: .redTolerance)
        try container.encode(instrumentSettings, forKey: .instrumentSettings)
        try container.encode(callouts, forKey: .callouts)
    }
    
    // Explicit Equatable to avoid synthesis pitfalls
    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        return lhs.speedUnit == rhs.speedUnit &&
        lhs.distanceUnit == rhs.distanceUnit &&
        lhs.yellowTolerance == rhs.yellowTolerance &&
        lhs.redTolerance == rhs.redTolerance &&
        lhs.instrumentSettings == rhs.instrumentSettings &&
        lhs.callouts == rhs.callouts
    }
    
    // Public memberwise initializer
    public init(
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit,
        yellowTolerance: Int,
        redTolerance: Int,
        instrumentSettings: [InstrumentSetting],
        callouts: CalloutSettings = .defaults
    ) {
        self.speedUnit = speedUnit
        self.distanceUnit = distanceUnit
        self.yellowTolerance = yellowTolerance
        self.redTolerance = redTolerance
        self.instrumentSettings = instrumentSettings
        self.callouts = callouts
    }
}

extension Settings {
    private static let speedUnitUDK = "speedUnit"
    private static let distanceUnitUDK = "distanceUnit"
    private static let yellowToleranceUDK = "yellowTolerance"
    private static let redToleranceUDK = "redTolerance"
    private static let instrumentSettingsUDK = "instrumentSettings"
    private static let calloutsUDK = "callouts"
    
    public static func load(from userDefaults: UserDefaults) -> Settings {
        let speedUnitString = userDefaults.string(forKey: speedUnitUDK) ?? SpeedUnit.kts.rawValue
        let speedUnit = SpeedUnit(rawValue: speedUnitString) ?? .kts
        
        let distanceUnitString = userDefaults.string(forKey: distanceUnitUDK) ?? DistanceUnit.nm.rawValue
        let distanceUnit = DistanceUnit(rawValue: distanceUnitString) ?? .nm
        
        // integer(forKey:) returns 0 for a never-set key, which would make every non-zero
        // delta red on a fresh install. Only trust the stored value when the key exists;
        // an explicitly saved 0 is still honoured.
        let yellowTolerance = userDefaults.object(forKey: yellowToleranceUDK) != nil
            ? userDefaults.integer(forKey: yellowToleranceUDK)
            : defaultYellowTolerance
        let redTolerance = userDefaults.object(forKey: redToleranceUDK) != nil
            ? userDefaults.integer(forKey: redToleranceUDK)
            : defaultRedTolerance

        let instrumentSettings: [InstrumentSetting] = {
            guard
                let data = userDefaults.data(forKey: instrumentSettingsUDK),
                let decoded = try? JSONDecoder().decode([LenientInstrumentSetting].self, from: data)
            else {
                return Settings.empty().instrumentSettings
            }
            return mergeInstrumentSettings(saved: decoded.compactMap(\.setting))
        }()

        // Missing or unreadable callout settings fall back to the defaults (F-01).
        let callouts = userDefaults.data(forKey: calloutsUDK)
            .flatMap { try? JSONDecoder().decode(CalloutSettings.self, from: $0) } ?? .defaults
        
        return Settings(
            speedUnit: speedUnit,
            distanceUnit: distanceUnit,
            yellowTolerance: yellowTolerance,
            redTolerance: redTolerance,
            instrumentSettings: instrumentSettings,
            callouts: callouts
        ).validated()
    }
    
    /// Rebuilds the instrument list from what the user saved (B-12).
    ///
    /// The saved order is the user's order, so it is kept as-is. Any default instrument the
    /// saved list lacks (a new instrument, or one that failed to decode) is appended enabled,
    /// and anything that is not a default instrument, or repeats an earlier entry, is dropped.
    static func mergeInstrumentSettings(saved: [InstrumentSetting]) -> [InstrumentSetting] {
        let defaults = Settings.empty().instrumentSettings
        let knownTypes = Set(defaults.map(\.type))
        var merged: [InstrumentSetting] = []
        var seen = Set<InFlightInfo>()
        for setting in saved where knownTypes.contains(setting.type) && seen.insert(setting.type).inserted {
            merged.append(setting)
        }
        for setting in defaults where !seen.contains(setting.type) {
            merged.append(setting)
        }
        return merged
    }

    /// Decodes one saved instrument entry, yielding `nil` instead of failing the whole array.
    ///
    /// `InstrumentSetting.init(from:)` throws on a type string this build does not know (for
    /// example one written by a newer or older build). Decoding the array as this wrapper lets
    /// a single stale element be dropped while the user's remaining layout survives.
    private struct LenientInstrumentSetting: Decodable {
        let setting: InstrumentSetting?

        init(from decoder: Decoder) throws {
            setting = try? InstrumentSetting(from: decoder)
        }
    }

    public func save(to userDefaults: UserDefaults) {
        userDefaults.set(speedUnit.rawValue, forKey: Self.speedUnitUDK)
        userDefaults.set(distanceUnit.rawValue, forKey: Self.distanceUnitUDK)
        userDefaults.set(yellowTolerance, forKey: Self.yellowToleranceUDK)
        userDefaults.set(redTolerance, forKey: Self.redToleranceUDK)
        
        if let encoded = try? JSONEncoder().encode(instrumentSettings) {
            userDefaults.set(encoded, forKey: Self.instrumentSettingsUDK)
        }
        if let encoded = try? JSONEncoder().encode(callouts) {
            userDefaults.set(encoded, forKey: Self.calloutsUDK)
        }
    }
}
