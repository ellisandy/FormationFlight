/// Helpers for formatting `Measurement` values (speed and distance) according to user unit preferences.
///
/// Returns short, localized strings using `MeasurementFormatter`, with `--` placeholders for missing values.
import Foundation

/// Namespace for measurement-formatting utilities.
enum MeasurementFormatters {
    /// Formats a speed measurement into a short, localized string using the specified unit preference.
    ///
    /// - Parameters:
    ///   - measurement: The speed to format. If `nil`, returns `"--"`.
    ///   - unitPreference: The preferred speed unit (knots, mph, or kph).
    /// - Returns: A string like `250 kt`, `140 mph`, or `200 km/h` with zero fractional digits.
    ///
    /// Notes:
    /// - The measurement is converted to the provided unit before formatting.
    /// - Fractional digits are suppressed (0 minimum/maximum).
    /// - The unit style is `.short` and the provided unit is preserved in output.
    static func speedString(_ measurement: Measurement<UnitSpeed>?, unitPreference: Settings.SpeedUnit) -> String {
        guard let m = measurement else { return "--" }
        let unit: UnitSpeed
        switch unitPreference {
        case .kts:
            unit = .knots
        case .mph:
            unit = .milesPerHour
        case .kph:
            unit = .kilometersPerHour
        }
        let converted = m.converted(to: unit)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter.string(from: converted)
    }
    
    /// Formats a distance measurement into a short, localized string using the specified unit preference.
    ///
    /// - Parameters:
    ///   - measurement: The distance to format. If `nil`, returns `"--"`.
    ///   - unitPreference: The preferred distance unit (nautical miles, miles, or kilometers).
    /// - Returns: A string like `12 nm`, `8 mi`, or `15 km` with zero fractional digits.
    ///
    /// Notes:
    /// - The measurement is converted to the provided unit before formatting.
    /// - Fractional digits are suppressed (0 minimum/maximum).
    /// - The unit style is `.short` and the provided unit is preserved in output.
    static func distanceString(_ measurement: Measurement<UnitLength>?, unitPreference: Settings.DistanceUnit) -> String {
        guard let m = measurement else { return "--" }
        let unit: UnitLength
        switch unitPreference {
        case .nm:
            unit = .nauticalMiles
        case .mi:
            unit = .miles
        case .km:
            unit = .kilometers
        }
        let converted = m.converted(to: unit)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.numberFormatter.minimumFractionDigits = 1
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter.string(from: converted)
    }
}

