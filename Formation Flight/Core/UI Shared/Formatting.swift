//
//  Formatting.swift
//  Formation Flight
//
//  Extracted helpers for display formatting.
//

import Foundation
import CoreLocation

// MARK: - Time Formatting (24-hour)
private extension DateFormatter {
    static let hhmmssPOSIX: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "HH:mm:ss"
        return df
    }()
}

private extension Duration {
    static let hmsPOSIXFormatter: Duration.TimeFormatStyle =
        .time(pattern: .hourMinuteSecond)
        .locale(Locale(identifier: "en_US_POSIX"))
}

// MARK: - Formatting Namespace
public enum Formatting {
    public static func timeHHmmss(_ date: Date?) -> String {
        if let _date = date {
            return DateFormatter.hhmmssPOSIX.string(from: _date)
        }
        return "--:--:--".uppercased()
    }
    
    public static func durationHMS(_ seconds: Double?) -> String {
        if let _seconds = seconds {
            let wholeSeconds = Int64(_seconds)
            let nanos = Int64((_seconds - Double(wholeSeconds)) * 1_000_000_000)
            let duration = Duration(secondsComponent: wholeSeconds, attosecondsComponent: nanos * 1_000_000_000)
            return duration.formatted(Duration.hmsPOSIXFormatter)
        }
        return "--:--:--".uppercased()
    }
    
    public static func angle(_ angle: Measurement<UnitAngle>?) -> String {
        if angle == nil || angle?.converted(to: .degrees).value == -1.0 { return "--" }
        let angleInt = angle?.converted(to: .degrees).value ?? 0
        return "\(Int(angleInt.rounded()).description.uppercased())°"
    }
    
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

