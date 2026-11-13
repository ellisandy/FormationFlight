//
//  MissionType.swift
//  FormationFlightCore
//
//  Created by Jack Ellis on 11/14/25.
//

/// Raw values are the SwiftData on-disk encoding of `Flight.missionType` and part of the
/// phone-to-watch payload (`FlightSnapshot`); they must not change.
public enum MissionType: String, Codable, CaseIterable, Sendable, RawRepresentable {
    case hackTime = "hack_time"
    case tot = "tot"
    /// A planned time on target that a Hack! press re-anchors: the flight is guided to the
    /// planned TOT until Hack! is pressed, then the TOT becomes the press plus the hack
    /// duration. Each later press re-anchors again (last press wins).
    case totHack = "tot_hack"

    /// `true` when the mission starts with a planned TOT (`missionDate`) and is guided to it
    /// from the start of the flight.
    public var usesPlannedTOT: Bool {
        switch self {
        case .tot, .totHack: true
        case .hackTime: false
        }
    }

    /// `true` when the mission carries a hack duration and the flight screen offers Hack!.
    public var usesHack: Bool {
        switch self {
        case .hackTime, .totHack: true
        case .tot: false
        }
    }
}
