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
}
