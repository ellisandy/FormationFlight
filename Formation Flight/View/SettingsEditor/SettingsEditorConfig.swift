//
//  FlightSettings.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import Foundation

struct SettingsEditorConfig {
    var isPresented = false

    var speedUnit: SpeedUnit
    var distanceUnit: DistanceUnit
    var yellowTolerance: Int
    var redTolerance: Int
    var minSpeed: Int
    var maxSpeed: Int
        
    private static let speedUnitUDK = "speedUnit"
    private static let distanceUnitUDK = "distanceUnit"
    private static let yellowToleranceUDK = "yellowTolerance"
    private static let redToleranceUDK = "redTolerance"
    private static let minSpeedUDK = "minSpeed"
    private static let maxSpeedUDK = "maxSpeed"


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
        
        return config
    }
    
    // Mostly for testing, but may be useful for initial bootstrapping
    static func emptyConfig() -> SettingsEditorConfig {
        return SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, minSpeed: 0, maxSpeed: 0)
    }
    
    func save(userDefaults: UserDefaults) {
        userDefaults.set(speedUnit.rawValue, forKey: SettingsEditorConfig.speedUnitUDK)
        userDefaults.set(distanceUnit.rawValue, forKey: SettingsEditorConfig.distanceUnitUDK)
        userDefaults.set(yellowTolerance, forKey: SettingsEditorConfig.yellowToleranceUDK)
        userDefaults.set(redTolerance, forKey: SettingsEditorConfig.redToleranceUDK)
        userDefaults.set(minSpeed, forKey: SettingsEditorConfig.minSpeedUDK)
        userDefaults.set(maxSpeed, forKey: SettingsEditorConfig.maxSpeedUDK)
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
    }
}
