/// Helpers for formatting `Measurement` values (speed and distance) according to user unit preferences.
///
/// Returns localized numbers followed by the unit symbol the Settings screen uses, with `--`
/// placeholders for missing values.
import Foundation
import FormationFlightCore

/// Namespace for measurement-formatting utilities.
enum MeasurementFormatters {
    /// Formats a speed measurement in the preferred unit, e.g. `250 kt`, `140 mph`, `200 km/h`.
    ///
    /// - Parameters:
    ///   - measurement: The speed to format. If `nil`, returns `"--"`.
    ///   - unitPreference: The preferred speed unit (knots, mph, or kph).
    /// - Returns: The converted value with zero fractional digits, a space, and the unit symbol.
    ///
    /// The symbol comes from `Settings.SpeedUnit.symbol` rather than `MeasurementFormatter`,
    /// whose "kn" disagreed with the "kt" pilots expect and Settings shows (D-09). The space
    /// before the unit follows system convention (D-05).
    static func speedString(_ measurement: Measurement<UnitSpeed>?, unitPreference: Settings.SpeedUnit) -> String {
        // Shared with the watch companion (F-02).
        FlightFormatting.speed(measurement, unit: unitPreference)
    }

    /// Formats a distance measurement in the preferred unit, e.g. `12.0 NM`, `8.0 mi`, `15.0 km`.
    ///
    /// - Parameters:
    ///   - measurement: The distance to format. If `nil`, returns `"--"`.
    ///   - unitPreference: The preferred distance unit (nautical miles, miles, or kilometers).
    /// - Returns: The converted value with one fractional digit, a space, and the unit symbol.
    ///
    /// The symbol comes from `Settings.DistanceUnit.symbol` (D-09); see `speedString`.
    static func distanceString(_ measurement: Measurement<UnitLength>?, unitPreference: Settings.DistanceUnit) -> String {
        FlightFormatting.distance(measurement, unit: unitPreference)
    }
}
