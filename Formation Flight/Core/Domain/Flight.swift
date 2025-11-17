//
//  Flight.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/17/23.
//

import Foundation
import SwiftData
import MapKit

/// Individual Planned Flight
@Model
final class Flight: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID = UUID()
    var missionName: String = ""
    var missionType: MissionType
    var missionDate: Date?
    var target: Target?
    var hackTime: TimeInterval?
    
    // TODO: Update the Comments here
    
    /// Initialize a Flight
    /// - Parameters:
    ///   - title: Title of the flight
    ///   - missionDate: Date of the mission
    init(missionName: String, missionType: MissionType, missionDate: Date? = nil, target: Target, hackTime: Double? = nil) {
        self.missionName = missionName
        self.missionType = missionType
        self.missionDate = missionDate
        self.target = target
        self.hackTime = hackTime
    }
}

extension Flight {
    static func == (lhs: Flight, rhs: Flight) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Flight {
    func validFlight() -> (valid: Bool, message: String?)  {
        var validStatus = true
        var message: String?
        
        if missionName.isEmpty {
            validStatus = false
            message = "Please enter a name for the mission"
        }
        
        if missionType == .hackTime && hackTime == nil {
            validStatus = false
            message = "Please enter a hack time"
        }
        
        if missionType == .tot && missionDate == nil {
            validStatus = false
            message = "Please enter a date for the mission"
        }
        
        if target == nil {
            validStatus = false
            message = "Please enter a target"
        }
        
        return (validStatus, message)
    }
}

extension Flight {
    var title: String {
        get { missionName }
        set { missionName = newValue }
    }
}
