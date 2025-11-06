//
//  FlightSettings.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import Foundation

struct InstrumentSetting: Identifiable, Codable, Equatable {
    let type: InFlightInfo
    var isEnabled: Bool
    var id: InFlightInfo { type }

    private enum CodingKeys: String, CodingKey {
        case type
        case isEnabled
    }

    init(type: InFlightInfo, isEnabled: Bool) {
        self.type = type
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode `type` as a raw string value
        let raw = try container.decode(String.self, forKey: .type)
        if let value = InFlightInfo(rawValue: raw) {
            self.type = value
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid InFlightInfo raw string: \(raw)"
            )
        }
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode `type` using its raw string value directly
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

struct SettingsEditorConfig {
    var isPresented = false

    var speedUnit: SpeedUnit
    var distanceUnit: DistanceUnit
    var yellowTolerance: Int
    var redTolerance: Int
    var minSpeed: Int
    var maxSpeed: Int
    var proximityToNextPoint: Double
    
    var instrumentSettings: [InstrumentSetting] = [
        InstrumentSetting(type: .tot, isEnabled: true),
        InstrumentSetting(type: .totDrift, isEnabled: true),
        InstrumentSetting(type: .finalBearing, isEnabled: true),
        InstrumentSetting(type: .nextBearing, isEnabled: true),
//        InstrumentSetting(type: .groundSpeed, isEnabled: true),
        InstrumentSetting(type: .currentTAS, isEnabled: true),
        InstrumentSetting(type: .targetTAS, isEnabled: true),
        InstrumentSetting(type: .distanceToFinal, isEnabled: true),
        InstrumentSetting(type: .distanceToNext, isEnabled: true)
    ]
        
    private static let speedUnitUDK = "speedUnit"
    private static let distanceUnitUDK = "distanceUnit"
    private static let yellowToleranceUDK = "yellowTolerance"
    private static let redToleranceUDK = "redTolerance"
    private static let minSpeedUDK = "minSpeed"
    private static let maxSpeedUDK = "maxSpeed"
    private static let instrumentSettingsUDK = "instrumentSettings"
    private static let proximityToNextPointUDK = "proximityToNextPoint"


    enum SpeedUnit: String, CaseIterable, Identifiable {
        case kts
        case kph
        case mph
        var id: Self { self }
    }
    
    func getUnitSpeed() -> UnitSpeed{
        switch speedUnit {
        case .kts:
            return UnitSpeed.knots
        case .kph:
            return UnitSpeed.kilometersPerHour
        case .mph:
            return UnitSpeed.milesPerHour
        }
    }
    
    enum DistanceUnit: String, CaseIterable, Identifiable {
        case km
        case mi
        case nm
        var id: Self { self }
    }
    
    func getDistanceUnits() -> UnitLength {
        switch distanceUnit {
        case .km:
            return UnitLength.kilometers
        case .mi:
            return UnitLength.miles
        case .nm:
            return UnitLength.nauticalMiles
        }
    }
    
    func getProximityToNextPointInMeters() -> Double {
        let measurement = Measurement<UnitLength>(value: proximityToNextPoint, unit: getDistanceUnits())
        return measurement.converted(to: .meters).value
    }
}

extension SettingsEditorConfig {
    static func from(userDefaults: UserDefaults) -> SettingsEditorConfig {
        var config = emptyConfig()
                
        // Sets default to Knots
        if let candidateSpeedUnit = SpeedUnit(rawValue: userDefaults.string(forKey: speedUnitUDK) ?? SpeedUnit.kts.rawValue) {
            config.speedUnit = candidateSpeedUnit
        }
        
        if let candidateDistanceUnit = DistanceUnit(rawValue: userDefaults.string(forKey: distanceUnitUDK) ?? DistanceUnit.nm.rawValue) {
            config.distanceUnit = candidateDistanceUnit
        }
        
        config.yellowTolerance = userDefaults.integer(forKey: yellowToleranceUDK)
        config.redTolerance = userDefaults.integer(forKey: redToleranceUDK)
        config.minSpeed = userDefaults.integer(forKey: minSpeedUDK)
        config.maxSpeed = userDefaults.integer(forKey: maxSpeedUDK)
        config.proximityToNextPoint = userDefaults.double(forKey: proximityToNextPointUDK)
        
        if let data = userDefaults.data(forKey: instrumentSettingsUDK),
           let decoded = try? JSONDecoder().decode([InstrumentSetting].self, from: data),
           !decoded.isEmpty {
            config.instrumentSettings = decoded
        }
        
        return config
    }
    
    // Mostly for testing, but may be useful for initial bootstrapping
    static func emptyConfig() -> SettingsEditorConfig {
        return SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, minSpeed: 0, maxSpeed: 0, proximityToNextPoint: 0.5)
    }
    
    func save(userDefaults: UserDefaults) {
        userDefaults.set(speedUnit.rawValue, forKey: SettingsEditorConfig.speedUnitUDK)
        userDefaults.set(distanceUnit.rawValue, forKey: SettingsEditorConfig.distanceUnitUDK)
        userDefaults.set(yellowTolerance, forKey: SettingsEditorConfig.yellowToleranceUDK)
        userDefaults.set(redTolerance, forKey: SettingsEditorConfig.redToleranceUDK)
        userDefaults.set(minSpeed, forKey: SettingsEditorConfig.minSpeedUDK)
        userDefaults.set(maxSpeed, forKey: SettingsEditorConfig.maxSpeedUDK)
        userDefaults.set(proximityToNextPoint, forKey: SettingsEditorConfig.proximityToNextPointUDK)
        
        if let data = try? JSONEncoder().encode(instrumentSettings) {
            userDefaults.set(data, forKey: SettingsEditorConfig.instrumentSettingsUDK)
        }
    }
    
    mutating func dismiss() {
        isPresented = false
    }
    
    mutating func present() {
        isPresented = true
    }
    
    mutating func reset(userDefaults: UserDefaults) {
        // Sets default to Knots
        if let candidateSpeedUnit = SpeedUnit(rawValue: userDefaults.string(forKey: SettingsEditorConfig.speedUnitUDK) ?? SpeedUnit.kts.rawValue) {
            speedUnit = candidateSpeedUnit
        }
        
        if let candidateDistanceUnit = DistanceUnit(rawValue: userDefaults.string(forKey: SettingsEditorConfig.distanceUnitUDK) ?? DistanceUnit.nm.rawValue) {
            distanceUnit = candidateDistanceUnit
        }
        
        yellowTolerance = userDefaults.integer(forKey: SettingsEditorConfig.yellowToleranceUDK)
        redTolerance = userDefaults.integer(forKey: SettingsEditorConfig.redToleranceUDK)
        minSpeed = userDefaults.integer(forKey: SettingsEditorConfig.minSpeedUDK)
        maxSpeed = userDefaults.integer(forKey: SettingsEditorConfig.maxSpeedUDK)
        
        if let data = userDefaults.data(forKey: SettingsEditorConfig.instrumentSettingsUDK),
           let decoded = try? JSONDecoder().decode([InstrumentSetting].self, from: data),
           !decoded.isEmpty {
            instrumentSettings = decoded
        }
    }
}

