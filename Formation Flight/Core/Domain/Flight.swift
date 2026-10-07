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

/// Version 1.0.0 of the persisted flight schema.
///
/// Any change to a persisted model must be made in a new `VersionedSchema` and wired into
/// `FlightMigrationPlan`, so stores written by older builds are migrated deliberately instead of
/// being lightweight-migrated into rows the current model cannot read.
enum FlightSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Flight.self] }

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
        var missionType: MissionType = MissionType.tot
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
}

/// The current persisted `Flight` model.
typealias Flight = FlightSchemaV1.Flight

/// Migration plan for the flight store.
///
/// Add each new `VersionedSchema` to `schemas` and a `MigrationStage` to `stages` describing how to
/// get there from the previous version. Stores written by a schema that is not listed here are
/// treated as unreadable and reset by `PersistenceController`.
enum FlightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FlightSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
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
            message = String(localized: "Please enter a name for the mission",
                             comment: "Flight validation: mission name is empty")
        }

        if missionType == .hackTime && hackTime == nil {
            validStatus = false
            message = String(localized: "Please enter a hack time",
                             comment: "Flight validation: hack-time mission has no hack time")
        }

        if missionType == .tot && missionDate == nil {
            validStatus = false
            message = String(localized: "Please enter a date for the mission",
                             comment: "Flight validation: time-on-target mission has no date")
        }

        if target == nil {
            validStatus = false
            message = String(localized: "Please enter a target",
                             comment: "Flight validation: no target selected")
        }

        return (validStatus, message)
    }
}
