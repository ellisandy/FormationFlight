//
//  Winds.swift
//  Formation Flight
//
//  Created by Jack Ellis on 1/15/24.
//

import Foundation
import SwiftData

struct Winds: Codable, Hashable {
    var velocityAsMetersPerSecond: Double
    var directionAsDegrees: Double
    
    init(velocity: Double, direction: Double, velocityUnit: UnitSpeed = UnitSpeed.knots, directionUnit: UnitAngle = UnitAngle.degrees) {
        self.velocityAsMetersPerSecond = Measurement(value: velocity, unit: velocityUnit).converted(to: .metersPerSecond).value
        self.directionAsDegrees = Measurement(value: direction, unit: directionUnit).converted(to: .degrees).value
    }

    var windVelocityAsText: String {
        get { velocity.value == 0 ? "" : "\(velocity.value)" }
        set { velocity.value = Double(newValue) ?? 0 }
    }
    
    var windDirectionAsText: String {
        get { direction.value == 0 ? "" : "\(direction.value)"}
        set { direction.value = Double(newValue) ?? 0 }
    }
    
    @Transient var velocity: Measurement<UnitSpeed> {
        get {
            return Measurement<UnitSpeed>(value: velocityAsMetersPerSecond, unit: .metersPerSecond)
        }
        set {
            velocityAsMetersPerSecond = newValue.value
        }
    }
    @Transient var direction: Measurement<UnitAngle> {
        get {
            return Measurement(value: directionAsDegrees, unit: .degrees)
        }
        set {
            directionAsDegrees = newValue.converted(to: .degrees).value
        }
    }
    
    func windComponents(given bearing: Double) -> (windCorrectionAngle: Double, windEffectiveVelocity: Double) {
        let windEffectiveVelocity = (velocity.value * cos((direction.value - bearing).degreesToRadians)) * -1
        
        return (0, windEffectiveVelocity)
    }
}
