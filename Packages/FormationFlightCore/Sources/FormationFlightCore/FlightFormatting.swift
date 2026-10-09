//
//  FlightFormatting.swift
//  FormationFlightCore
//
//  Display strings shared by the phone's flight screen, its Live Activity and the watch
//  companion (F-02), moved here from the app so all three render the same readout the same way.
//  The app's `Formatting` and `MeasurementFormatters` forward to these.
//
//  Not called `Formatting`: the app keeps its own `Formatting` namespace, and two types of the
//  same name would make every file importing both ambiguous.
//

import Foundation

public enum FlightFormatting {
    /// Placeholder for a missing or unrepresentable duration.
    public static let durationPlaceholder = "--:--:--"

    /// Formats a duration in seconds as `HH:mm:ss`.
    ///
    /// - Returns: A zero-padded `HH:mm:ss` string of the magnitude. Negative durations are
    ///   prefixed with `-` (e.g. `-00:01:05`); non-negative durations carry no sign. `nil` or a
    ///   non-finite value gives `--:--:--`.
    ///
    /// Fractional seconds are truncated, not rounded (B-40). The sign follows the sign of the
    /// input, so `-0.5` renders as `-00:00:00`.
    public static func durationHMS(_ seconds: TimeInterval?) -> String {
        guard let seconds, let components = hmsComponents(seconds) else {
            return durationPlaceholder
        }
        let sign = seconds < 0 ? "-" : ""
        return sign + components
    }

    /// Formats a duration in seconds as `HH:mm:ss` with an explicit leading sign, for the
    /// early/late (Δ) readout where an unsigned value would be ambiguous.
    ///
    /// - Returns: The magnitude prefixed with `+` or `-` (e.g. `+00:00:07`, `-00:01:05`).
    ///   Anything under a whole second either way renders as an unsigned `00:00:00` (B-46):
    ///   the sign follows the digits shown, not the fraction they drop.
    public static func signedDurationHMS(_ seconds: TimeInterval?) -> String {
        guard let seconds, let components = hmsComponents(seconds) else {
            return durationPlaceholder
        }
        guard abs(seconds) >= 1 else { return components }
        let sign = seconds < 0 ? "-" : "+"
        return sign + components
    }

    /// Compact `m:ss`, or `h:mm:ss` from an hour up, of the magnitude, for small screens (Live
    /// Activity, watch). Truncates like `durationHMS`; `--:--` when nil or non-finite.
    ///
    /// - Parameter signed: Prefix `+` / `-` as `signedDurationHMS` does, for Δ.
    public static func compactDuration(_ seconds: TimeInterval?, signed: Bool = false) -> String {
        guard let seconds, seconds.isFinite, abs(seconds) < Double(Int.max) else { return "--:--" }
        let total = Int(abs(seconds))
        let hours = total / 3600, minutes = total % 3600 / 60, secs = total % 60
        let body = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
        let sign: String
        if signed {
            sign = total == 0 ? "" : (seconds < 0 ? "-" : "+")
        } else {
            sign = seconds < 0 && total > 0 ? "-" : ""
        }
        return sign + body
    }

    /// A speed in the pilot's unit, e.g. `250 kt`, `140 mph`, `200 km/h`; `--` when nil.
    ///
    /// The symbol is `SpeedUnit.symbol` rather than `MeasurementFormatter`'s, whose "kn"
    /// disagreed with the "kt" pilots expect (D-09). Space before the unit per system
    /// convention (D-05).
    public static func speed(_ measurement: Measurement<UnitSpeed>?, unit: SpeedUnit) -> String {
        guard let measurement else { return "--" }
        return format(measurement.converted(to: unit.unitSpeed).value, fractionDigits: 0, symbol: unit.symbol)
    }

    /// `speed(_:unit:)` from metres per second, the unit `FlightSnapshot` and `TimingEngine` use.
    public static func speed(metersPerSecond: Double?, unit: SpeedUnit) -> String {
        speed(metersPerSecond.map { Measurement(value: $0, unit: UnitSpeed.metersPerSecond) }, unit: unit)
    }

    /// A distance in the pilot's unit with one decimal, e.g. `12.0 NM`; `--` when nil (D-09).
    public static func distance(_ measurement: Measurement<UnitLength>?, unit: DistanceUnit) -> String {
        guard let measurement else { return "--" }
        return format(measurement.converted(to: unit.unitLength).value, fractionDigits: 1, symbol: unit.symbol)
    }

    /// `distance(_:unit:)` from metres.
    public static func distance(meters: Double?, unit: DistanceUnit) -> String {
        distance(meters.map { Measurement(value: $0, unit: UnitLength.meters) }, unit: unit)
    }

    /// The turn the ETE assumes, e.g. "TURN 0:45 R" (B-45); nil with no turn modelled.
    public static func turnCaption(duration: TimeInterval?, direction: TurnToTarget.Direction?) -> String? {
        guard let duration, duration.isFinite, duration >= 0, duration < Double(Int.max),
              let direction else { return nil }
        let total = Int(duration)
        let time = String(format: "%d:%02d", total / 60, total % 60)
        switch direction {
        case .left:
            return String(localized: "TURN \(time) L", bundle: .module, comment: "Flight ETE row: modelled turn-in, minutes:seconds, to the left")
        case .right:
            return String(localized: "TURN \(time) R", bundle: .module, comment: "Flight ETE row: modelled turn-in, minutes:seconds, to the right")
        }
    }

    // MARK: Private

    /// The magnitude of `seconds` as zero-padded `HH:mm:ss`, fractional seconds truncated;
    /// nil when non-finite or too large for `Int` (B-34: `Int(_:)` traps on those).
    private static func hmsComponents(_ seconds: TimeInterval) -> String? {
        let magnitude = abs(seconds)
        guard magnitude.isFinite, magnitude < Double(Int.max) else { return nil }
        let total = Int(magnitude)
        return String(format: "%02d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }

    /// Locale-aware number (grouping and decimal separator), a space, and `symbol`.
    private static func format(_ value: Double, fractionDigits: Int, symbol: String) -> String {
        let number = value.formatted(.number.precision(.fractionLength(fractionDigits)))
        return "\(number) \(symbol)"
    }
}
