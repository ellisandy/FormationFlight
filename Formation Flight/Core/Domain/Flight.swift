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

/// The single set of rules that decide whether a mission can be saved or flown (B-14).
///
/// Both `Flight.validFlight()` (persistence) and `FlightEditorViewModel.goFlyValidationMessage`
/// (Go Fly) call `message(...)`, so each rule has exactly one wording and the string catalog
/// carries it once. The function takes plain values rather than a `Flight` so the editor can
/// validate its draft before a model exists.
enum FlightValidation {
    /// How far in the past a time on target may be and still be accepted, in seconds.
    ///
    /// A pilot who sets the TOT to "now" and then takes a moment to press Save or Go Fly must
    /// not be refused, so there is a short grace period rather than a hard `>= now` check.
    static let pastTOTGrace: TimeInterval = 60

    /// Returns the user-facing message for the first failing rule, or `nil` when the values
    /// describe a flyable mission.
    ///
    /// Rules are checked in the order the editor lays the fields out: name, target, then the
    /// time entry for the selected mission type.
    static func message(missionName: String,
                        missionType: MissionType,
                        missionDate: Date?,
                        hackTime: TimeInterval?,
                        hasTarget: Bool,
                        now: Date = Date()) -> String? {
        if missionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return missingNameMessage
        }
        if !hasTarget {
            return missingTargetMessage
        }
        switch missionType {
        case .hackTime:
            guard let hackTime, hackTime.isFinite, hackTime > 0 else {
                return missingHackTimeMessage
            }
        case .tot:
            guard let missionDate else {
                return missingMissionDateMessage
            }
            if missionDate < now.addingTimeInterval(-pastTOTGrace) {
                return pastTOTMessage
            }
        }
        return nil
    }

    static var missingNameMessage: String {
        String(localized: "Please enter a mission name.",
               comment: "Validation message when a flight has no mission name")
    }

    static var missingTargetMessage: String {
        String(localized: "Please enter a valid target location.",
               comment: "Validation message when a flight has no target selected")
    }

    static var missingHackTimeMessage: String {
        String(localized: "Please enter a hack time.",
               comment: "Validation message when a hack-time mission has no hack duration or a zero one")
    }

    static var missingMissionDateMessage: String {
        String(localized: "Please enter a mission date and time.",
               comment: "Validation message when a time-on-target mission has no date")
    }

    static var pastTOTMessage: String {
        String(localized: "The time on target is in the past.",
               comment: "Validation message when a time-on-target mission is scheduled more than a minute ago")
    }
}

/// Validation helpers.
extension Flight {
    /// Validates the flight based on mission type and required fields.
    ///
    /// Delegates to `FlightValidation.message(...)`, the single source of truth shared with the
    /// editor's Go Fly gate.
    ///
    /// - Parameter now: The current time, injectable for tests of the past-TOT rule.
    /// - Returns: A tuple `(valid, message)` where `valid` indicates overall validity and
    ///   `message` provides a user-facing prompt for the first failing rule, if any.
    func validFlight(now: Date = Date()) -> (valid: Bool, message: String?) {
        let message = FlightValidation.message(missionName: missionName,
                                               missionType: missionType,
                                               missionDate: missionDate,
                                               hackTime: hackTime,
                                               hasTarget: target != nil,
                                               now: now)
        return (message == nil, message)
    }
}
