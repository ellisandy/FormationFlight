//
//  Formatting.swift
//  Formation Flight
//
//  Extracted helpers for display formatting.
///
/// Formatting helpers used across the app for consistent, locale-stable display of times,
/// durations, angles, and geographic coordinates.
///
/// - Time and Duration: Uses POSIX locale to ensure fixed 24-hour formatting regardless of user settings.
/// - Angles: Provides degree-based string output with fallback placeholders for invalid/unknown values.
/// - Coordinates: Formats latitude/longitude as degrees and decimal minutes with hemisphere prefixes.
//

import Foundation
import CoreLocation

/// Cached date formatter(s) configured with an `en_US_POSIX` locale for stable 24-hour time output.
///
/// Using a static formatter avoids the overhead of repeatedly creating `DateFormatter` instances
/// and guarantees consistent formatting independent of the user's locale preferences.
private extension DateFormatter {
    /// 24-hour time formatter producing strings in the form `HH:mm:ss` using the POSIX locale.
    static let hhmmssPOSIX: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "HH:mm:ss"
        return df
    }()
}

/// Reusable `Duration.TimeFormatStyle` configured for hour–minute–second output in the POSIX locale.
private extension Duration {
    /// A time format style that renders durations as `HH:mm:ss` regardless of user locale.
    static let hmsPOSIXFormatter: Duration.TimeFormatStyle = {
        var style: Duration.TimeFormatStyle = .time(pattern: .hourMinuteSecond)
        style.locale = Locale(identifier: "en_US_POSIX")
        return style
    }()
}

/// Namespace for common display formatting utilities.
///
/// All functions return uppercase placeholders (e.g., `--:--:--`, `--`) when input values are missing
/// or represent sentinel "unknown" values. Functions prefer POSIX-stable output where applicable.
public enum Formatting {
    /// Formats a `Date` as a 24-hour time string `HH:mm:ss` using a POSIX-stable formatter.
    ///
    /// - Parameter date: The date to format. If `nil`, a placeholder `--:--:--` is returned.
    /// - Returns: A string such as `14:07:52`, or `--:--:--` if `date` is `nil`.
    public static func timeHHmmss(_ date: Date?) -> String {
        guard let date else { return "--:--:--".uppercased() }
        
        return DateFormatter.hhmmssPOSIX.string(from: date)
    }
    
    /// Formats a duration in seconds as `HH:mm:ss`.
    ///
    /// - Parameter seconds: The duration in seconds. If `nil`, returns `--:--:--`.
    /// - Returns: A zero-padded `HH:mm:ss` string.
    ///
    /// Note: This implementation performs simple integer division and modulo operations and
    /// does not round to the nearest second. Fractional seconds are truncated.
    public static func durationHMS(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "--:--:--".uppercased() }
        let hours = Int(seconds / 3600)
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    /// Formats an angle measurement as whole degrees with a trailing degree symbol (e.g., `42°`).
    ///
    /// - Parameter angle: The angle as a `Measurement<UnitAngle>`. If `nil` or non-positive, returns `--`.
    /// - Returns: A rounded, integer degree string (e.g., `90°`) or `--` for invalid/unknown values.
    public static func angle(_ angle: Measurement<UnitAngle>?) -> String {
        guard let measurement = angle else { return "--" }
        let degrees = measurement.converted(to: .degrees).value
        let rounded = degrees.rounded()
        if degrees <= 0 { return "--" }
        return "\(Int(rounded).description.uppercased())°"
    }
    
    /// Formats a degree value as whole degrees with a trailing degree symbol.
    ///
    /// - Parameter degrees: Degrees as `Double`. `nil` or a sentinel value of `-1` yields `--`.
    /// - Returns: A rounded, integer degree string (e.g., `270°`) or `--`.
    public static func angle(degrees: Double?) -> String {
        guard let value = degrees else { return "--" }
        if value == -1 { return "--" }
        return "\(Int(value.rounded()).description.uppercased())°"
    }
    
    /// Convenience overload for degree input.
    ///
    /// - Parameter angle: Degrees as `Double`.
    /// - Returns: A rounded, integer degree string (e.g., `15°`).
    public static func angle(degrees angle: Double) -> String {
        self.angle(Measurement(value: angle, unit: .degrees)).uppercased()
    }
    
    /// Convenience overload for integer degree input.
    ///
    /// - Parameter angle: Degrees as `Int`.
    /// - Returns: A rounded, integer degree string (e.g., `180°`).
    ///
    /// - Note: Internally converts the integer value to a `Measurement` and returns uppercase output.
    public static func angle(degrees angle: Int) -> String {
        return self.angle(Measurement(value: Double(angle), unit: .radians)).uppercased()
    }
    
    /// Formats a coordinate as degrees and decimal minutes with hemisphere prefixes.
    ///
    /// Output example: `N 37 46.50`, `W 122 25.10`.
    ///
    /// - Parameter coordinate: The coordinate to format. If `nil`, returns empty strings.
    /// - Returns: A tuple containing latitude and longitude strings.
    public static func dms(from coordinate: CLLocationCoordinate2D?) -> (lat: String, lon: String) {
        guard let target = coordinate else { return ("", "") }
        func format(value: Double, positiveHemisphere: String, negativeHemisphere: String) -> String {
            let hemisphere = value >= 0 ? positiveHemisphere : negativeHemisphere
            let absValue = abs(value)
            let degrees = Int(absValue)
            let minutesDecimal = (absValue - Double(degrees)) * 60
            let minutes = String(format: "%02.2f", minutesDecimal)
            return "\(hemisphere) \(degrees) \(minutes)"
        }
        let lat = format(value: target.latitude, positiveHemisphere: "N", negativeHemisphere: "S")
        let lon = format(value: target.longitude, positiveHemisphere: "E", negativeHemisphere: "W")
        return (lat, lon)
    }
}

