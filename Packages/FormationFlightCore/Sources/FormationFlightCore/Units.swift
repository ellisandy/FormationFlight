//
//  Units.swift
//  FormationFlightCore
//
//  The pilot's display units. Moved out of the app's `Settings` so the callout engine, the
//  Live Activity and the watch can format speeds without depending on app settings storage.
//  The app keeps `Settings.SpeedUnit` / `Settings.DistanceUnit` as typealiases of these.
//

import Foundation

/// Raw values are the persisted encoding (UserDefaults and `Settings`' Codable form) and are
/// part of the phone-to-watch payload (`FlightSnapshot`), so they must not change; `symbol` is
/// what the UI shows.
public enum SpeedUnit: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case kts, kph, mph
    public var id: Self { self }

    /// Displayed unit symbol, shared by Settings and the flight screen (D-09). Aviation
    /// convention for knots is "kt".
    public var symbol: String {
        switch self {
        case .kts: return "kt"
        case .kph: return "km/h"
        case .mph: return "mph"
        }
    }

    /// The Foundation unit for converting a `Measurement<UnitSpeed>` into this display unit.
    public var unitSpeed: UnitSpeed {
        switch self {
        case .kts: return .knots
        case .kph: return .kilometersPerHour
        case .mph: return .milesPerHour
        }
    }
}

/// Raw values are the persisted encoding and part of the phone-to-watch payload, so they must
/// not change; `symbol` is what the UI shows.
public enum DistanceUnit: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case km, mi, nm
    public var id: Self { self }

    /// Displayed unit symbol, shared by Settings and the flight screen (D-09). Aviation
    /// convention for nautical miles is "NM".
    public var symbol: String {
        switch self {
        case .km: return "km"
        case .mi: return "mi"
        case .nm: return "NM"
        }
    }

    /// The Foundation unit for converting a `Measurement<UnitLength>` into this display unit.
    public var unitLength: UnitLength {
        switch self {
        case .km: return .kilometers
        case .mi: return .miles
        case .nm: return .nauticalMiles
        }
    }
}
