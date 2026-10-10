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
import FormationFlightCore

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
    
    /// Formats a duration in seconds as `HH:mm:ss`; `--:--:--` for nil or non-finite input.
    /// Negative durations are prefixed with `-`; fractional seconds are truncated, not rounded.
    ///
    /// Forwards to `FlightFormatting` in FormationFlightCore so the watch companion (F-02)
    /// renders durations exactly as the flight screen does.
    public static func durationHMS(_ seconds: TimeInterval?) -> String {
        FlightFormatting.durationHMS(seconds)
    }

    /// Formats a duration in seconds as `HH:mm:ss` with an explicit leading sign, for Δ;
    /// under a whole second renders unsigned (B-46). Forwards to `FlightFormatting` (F-02).
    public static func signedDurationHMS(_ seconds: TimeInterval?) -> String {
        FlightFormatting.signedDurationHMS(seconds)
    }

    /// B-34: `Int(_:)` traps on NaN, ±infinity, and any magnitude at or beyond `Int.max`.
    /// Every `Int(Double)` conversion in this file goes through this check first so bad
    /// input degrades to a placeholder instead of taking the app down.
    private static func isIntRepresentable(_ value: Double) -> Bool {
        value.isFinite && abs(value) < Double(Int.max)
    }

    /// Formats an angle measurement as a three-digit compass bearing (e.g., `042°`).
    ///
    /// - Parameter angle: The angle as a `Measurement<UnitAngle>`. If `nil`, negative (the
    ///   CoreLocation "unknown" sentinel is `-1`), or non-finite (NaN, ±inf, or beyond `Int`
    ///   range), returns `--`.
    /// - Returns: A rounded, zero-padded degree string in `000°`...`359°`, or `--`.
    public static func angle(_ angle: Measurement<UnitAngle>?) -> String {
        guard let measurement = angle else { return "--" }
        return formatDegrees(measurement.converted(to: .degrees).value)
    }

    /// Formats a degree value as a three-digit compass bearing.
    ///
    /// - Parameter degrees: Degrees as `Double`. `nil`, a negative value (sentinel `-1`), or a
    ///   non-finite value (NaN, ±inf, or beyond `Int` range) yields `--`.
    /// - Returns: A rounded, zero-padded degree string (e.g., `270°`) or `--`.
    public static func angle(degrees: Double?) -> String {
        guard let value = degrees else { return "--" }
        return formatDegrees(value)
    }

    /// Convenience overload for degree input.
    ///
    /// - Parameter angle: Degrees as `Double`.
    /// - Returns: A rounded, zero-padded degree string (e.g., `015°`).
    public static func angle(degrees angle: Double) -> String {
        formatDegrees(angle)
    }

    /// Convenience overload for integer degree input.
    ///
    /// - Parameter angle: Degrees as `Int`.
    /// - Returns: A zero-padded degree string (e.g., `180°`).
    public static func angle(degrees angle: Int) -> String {
        // B-10: this used to build the Measurement in radians, so 90 printed as "5157°".
        self.angle(Measurement(value: Double(angle), unit: .degrees))
    }

    /// Shared body of the `angle` family (B-10).
    ///
    /// - `< 0` is the only sentinel: 0° (due north) is a real bearing and must render.
    /// - Non-finite or absurdly large input is rejected before any `Int(_:)` conversion (B-34).
    /// - The value is rounded first and then normalised into `0..<360`, so 359.6° becomes
    ///   `000°` rather than `360°`.
    /// - Output is always three digits, as read off a compass card.
    private static func formatDegrees(_ degrees: Double) -> String {
        guard isIntRepresentable(degrees) else { return "--" }
        if degrees < 0 { return "--" }
        let normalised = degrees.rounded().truncatingRemainder(dividingBy: 360)
        return String(format: "%03d°", Int(normalised))
    }
    
    /// Formats a coordinate as degrees and decimal minutes with hemisphere prefixes.
    ///
    /// Output example: `N 37 46.50`, `W 122 25.10`.
    ///
    /// - Parameter coordinate: The coordinate to format. If `nil`, or if either component is
    ///   non-finite (NaN, ±inf, or beyond `Int` range), returns empty strings.
    /// - Returns: A tuple containing latitude and longitude strings.
    public static func dms(from coordinate: CLLocationCoordinate2D?) -> (lat: String, lon: String) {
        guard let target = coordinate else { return ("", "") }
        // B-34: both components feed Int(absValue); a bad value in either makes the whole
        // coordinate meaningless, so fall back to the same placeholder as a missing coordinate.
        guard isIntRepresentable(target.latitude), isIntRepresentable(target.longitude) else {
            return ("", "")
        }
        func format(value: Double, positiveHemisphere: String, negativeHemisphere: String) -> String {
            let hemisphere = value >= 0 ? positiveHemisphere : negativeHemisphere
            let absValue = abs(value)
            let degrees = Int(absValue)
            let minutesDecimal = (absValue - Double(degrees)) * 60
            // B-10: `%05.2f` is the whole field width (two integer digits, point, two decimals),
            // so minutes below 10 are zero-padded ("05.00"). `%02.2f` only promised two
            // characters in total and never padded.
            let minutes = String(format: "%05.2f", minutesDecimal)
            return "\(hemisphere) \(degrees) \(minutes)"
        }
        let lat = format(value: target.latitude, positiveHemisphere: "N", negativeHemisphere: "S")
        let lon = format(value: target.longitude, positiveHemisphere: "E", negativeHemisphere: "W")
        return (lat, lon)
    }
}

