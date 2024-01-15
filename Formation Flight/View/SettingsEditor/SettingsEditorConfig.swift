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
    var yellowTolerance: Int
    var redTolerance: Int
    var minSpeed: Int
    var maxSpeed: Int
        
    private static let speedUnitUDK = "speedUnit"
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
}

extension SettingsEditorConfig {
    static func from(userDefaults: UserDefaults) -> SettingsEditorConfig {
        var config = emptyConfig()
                
        // Sets default to Knots
        if let unit = SpeedUnit(rawValue: userDefaults.string(forKey: speedUnitUDK) ?? SpeedUnit.kts.rawValue) {
            config.speedUnit = unit
        }
        
        config.yellowTolerance = userDefaults.integer(forKey: yellowToleranceUDK)
        config.redTolerance = userDefaults.integer(forKey: redToleranceUDK)
        config.minSpeed = userDefaults.integer(forKey: minSpeedUDK)
        config.maxSpeed = userDefaults.integer(forKey: maxSpeedUDK)
        
        return config
    }
    
    // Mostly for testing, but may be useful for initial bootstrapping
    static func emptyConfig() -> SettingsEditorConfig {
        return SettingsEditorConfig(speedUnit: .kts, yellowTolerance: 0, redTolerance: 0, minSpeed: 0, maxSpeed: 0)
    }
    
    func save(userDefaults: UserDefaults) {
        userDefaults.set(speedUnit.rawValue, forKey: SettingsEditorConfig.speedUnitUDK)
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
        if let unit = SpeedUnit(rawValue: userDefaults.string(forKey: SettingsEditorConfig.speedUnitUDK) ?? SpeedUnit.kts.rawValue) {
            speedUnit = unit
        }
        
        yellowTolerance = userDefaults.integer(forKey: SettingsEditorConfig.yellowToleranceUDK)
        redTolerance = userDefaults.integer(forKey: SettingsEditorConfig.redToleranceUDK)
        minSpeed = userDefaults.integer(forKey: SettingsEditorConfig.minSpeedUDK)
        maxSpeed = userDefaults.integer(forKey: SettingsEditorConfig.maxSpeedUDK)
    }
}
