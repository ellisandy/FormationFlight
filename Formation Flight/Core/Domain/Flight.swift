//
//  Flight.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/17/23.
//

/// Flight model representing a planned mission in Formation Flight.
///
/// Persisted with SwiftData via `@Model`, this type captures mission metadata including name,
/// type, scheduled date/time, target location, and optional hack time. It conforms to
/// `Identifiable` and `Hashable` for use in SwiftUI lists and collections.

import Foundation
import SwiftData
import MapKit

/// An individual planned flight/mission.
///
/// - Note: `missionType` determines which fields are required for validity:
///   - `.hackTime` requires `hackTime` to be non-nil.
///   - `.tot` requires `missionDate` to be non-nil.
@Model
final class Flight: Identifiable, Hashable {
    /// Stable unique identifier for the flight. Marked unique for persistence.
    @Attribute(.unique) var id: UUID = UUID()
    /// Human-readable mission name used for display.
    var missionName: String = ""
    /// The mission type, which drives validation requirements (e.g., TOT vs Hack Time).
    var missionType: MissionType
    /// The scheduled date/time for time-on-target (TOT) missions. Optional.
    var missionDate: Date?
    /// The selected mission target. Required for a valid flight.
    var target: Target?
    /// Hack time in seconds for hack-time-driven missions. Optional.
    var hackTime: TimeInterval?
    
    /// Creates a new `Flight`.
    ///
    /// - Parameters:
    ///   - missionName: Title of the mission for display.
    ///   - missionType: The mission type that dictates validation rules.
    ///   - missionDate: Optional date/time for TOT missions.
    ///   - target: The mission's target.
    ///   - hackTime: Optional hack time in seconds for hack-time missions.
    init(missionName: String, missionType: MissionType, missionDate: Date? = nil, target: Target, hackTime: Double? = nil) {
        self.missionName = missionName
        self.missionType = missionType
        self.missionDate = missionDate
        self.target = target
        self.hackTime = hackTime
    }
}

/// Hashable and Equatable conformance based on the unique identifier.
extension Flight {
    static func == (lhs: Flight, rhs: Flight) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Validation helpers.
extension Flight {
    /// Validates the flight based on mission type and required fields.
    ///
    /// - Returns: A tuple `(valid, message)` where `valid` indicates overall validity and
    ///   `message` provides a user-facing prompt for the first missing requirement, if any.
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

/// Convenience property aliases.
extension Flight {
    /// Alias for `missionName` to support legacy call sites.
    var title: String {
        get { missionName }
        set { missionName = newValue }
    }
}
