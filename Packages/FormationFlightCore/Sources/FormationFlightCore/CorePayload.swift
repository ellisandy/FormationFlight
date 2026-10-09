//
//  CorePayload.swift
//  FormationFlightCore
//

import Foundation

/// Package-wide payload constants.
///
/// Deliberately not named after the module: a type called `FormationFlightCore` would shadow
/// the module name and stop clients from writing `FormationFlightCore.SpeedUnit`.
public enum CorePayload {
    /// Version of the phone-to-watch and Live Activity payloads. Bump on a breaking change.
    public static let version = 1
}
