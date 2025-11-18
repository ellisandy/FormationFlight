import Foundation

public struct Settings: Codable, Equatable {
    public var speedUnit: SpeedUnit
    public var distanceUnit: DistanceUnit
    public var yellowTolerance: Int
    public var redTolerance: Int
    public var instrumentSettings: [InstrumentSetting]
    
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
    
    public enum SpeedUnit: String, CaseIterable, Identifiable, Codable, Equatable {
        case kts, kph, mph
        public var id: Self { self }
    }
    
    public enum DistanceUnit: String, CaseIterable, Identifiable, Codable, Equatable {
        case km, mi, nm
        public var id: Self { self }
    }
    
    public static func empty() -> Settings {
        return Settings(
            speedUnit: .kts,
            distanceUnit: .nm,
            yellowTolerance: 0,
            redTolerance: 0,
            instrumentSettings: [
                InstrumentSetting(type: .currentGroundSpeed, isEnabled: true),
                InstrumentSetting(type: .requiredGroundSpeed, isEnabled: true),
                InstrumentSetting(type: .distance, isEnabled: true),
                InstrumentSetting(type: .bearing, isEnabled: true),
                InstrumentSetting(type: .track, isEnabled: true),
            ]
        )
    }
    
    // Explicit CodingKeys to ensure stable Codable synthesis
    private enum CodingKeys: String, CodingKey {
        case speedUnit
        case distanceUnit
        case yellowTolerance
        case redTolerance
        case instrumentSettings
    }
    
    // Explicit init(from:) to avoid any synthesis issues
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.speedUnit = try container.decode(SpeedUnit.self, forKey: .speedUnit)
        self.distanceUnit = try container.decode(DistanceUnit.self, forKey: .distanceUnit)
        self.yellowTolerance = try container.decode(Int.self, forKey: .yellowTolerance)
        self.redTolerance = try container.decode(Int.self, forKey: .redTolerance)
        self.instrumentSettings = try container.decode([InstrumentSetting].self, forKey: .instrumentSettings)
    }
    
    // Explicit encode(to:)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(speedUnit, forKey: .speedUnit)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(yellowTolerance, forKey: .yellowTolerance)
        try container.encode(redTolerance, forKey: .redTolerance)
        try container.encode(instrumentSettings, forKey: .instrumentSettings)
    }
    
    // Explicit Equatable to avoid synthesis pitfalls
    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        return lhs.speedUnit == rhs.speedUnit &&
        lhs.distanceUnit == rhs.distanceUnit &&
        lhs.yellowTolerance == rhs.yellowTolerance &&
        lhs.redTolerance == rhs.redTolerance &&
        lhs.instrumentSettings == rhs.instrumentSettings
    }
    
    // Public memberwise initializer
    public init(
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit,
        yellowTolerance: Int,
        redTolerance: Int,
        instrumentSettings: [InstrumentSetting]
    ) {
        self.speedUnit = speedUnit
        self.distanceUnit = distanceUnit
        self.yellowTolerance = yellowTolerance
        self.redTolerance = redTolerance
        self.instrumentSettings = instrumentSettings
    }
}

extension Settings {
    private static let speedUnitUDK = "speedUnit"
    private static let distanceUnitUDK = "distanceUnit"
    private static let yellowToleranceUDK = "yellowTolerance"
    private static let redToleranceUDK = "redTolerance"
    private static let instrumentSettingsUDK = "instrumentSettings"
    
    public static func load(from userDefaults: UserDefaults) -> Settings {
        let speedUnitString = userDefaults.string(forKey: speedUnitUDK) ?? SpeedUnit.kts.rawValue
        let speedUnit = SpeedUnit(rawValue: speedUnitString) ?? .kts
        
        let distanceUnitString = userDefaults.string(forKey: distanceUnitUDK) ?? DistanceUnit.nm.rawValue
        let distanceUnit = DistanceUnit(rawValue: distanceUnitString) ?? .nm
        
        let yellowTolerance = userDefaults.integer(forKey: yellowToleranceUDK)
        let redTolerance = userDefaults.integer(forKey: redToleranceUDK)
        
        let instrumentSettings: [InstrumentSetting] = {
            guard
                let data = userDefaults.data(forKey: instrumentSettingsUDK),
                let decoded = try? JSONDecoder().decode([InstrumentSetting].self, from: data)
            else {
                return Settings.empty().instrumentSettings
            }
            // Merge logic: preserve saved isEnabled for saved types, add missing defaults enabled by default
            let defaults = Settings.empty().instrumentSettings
            var merged = defaults
            for (index, def) in defaults.enumerated() {
                if let saved = decoded.first(where: { $0.type == def.type }) {
                    merged[index].isEnabled = saved.isEnabled
                }
            }
            return merged
        }()
        
        return Settings(
            speedUnit: speedUnit,
            distanceUnit: distanceUnit,
            yellowTolerance: yellowTolerance,
            redTolerance: redTolerance,
            instrumentSettings: instrumentSettings
        )
    }
    
    public func save(to userDefaults: UserDefaults) {
        userDefaults.set(speedUnit.rawValue, forKey: Self.speedUnitUDK)
        userDefaults.set(distanceUnit.rawValue, forKey: Self.distanceUnitUDK)
        userDefaults.set(yellowTolerance, forKey: Self.yellowToleranceUDK)
        userDefaults.set(redTolerance, forKey: Self.redToleranceUDK)
        
        if let encoded = try? JSONEncoder().encode(instrumentSettings) {
            userDefaults.set(encoded, forKey: Self.instrumentSettingsUDK)
        }
    }
}
