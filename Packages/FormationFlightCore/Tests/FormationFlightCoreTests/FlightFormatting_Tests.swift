import Foundation
import Testing
@testable import FormationFlightCore

/// Display strings shared by the phone, the Live Activity and the watch (F-02). The app's
/// `FormattingTests` and `MeasurementFormattersTests` cover the same rules through its wrappers.
@Suite("FlightFormatting")
struct FlightFormattingTests {
    @Test("HH:mm:ss truncates and signs like the flight screen")
    func hms() {
        #expect(FlightFormatting.durationHMS(65.9) == "00:01:05")
        #expect(FlightFormatting.durationHMS(-65) == "-00:01:05")
        #expect(FlightFormatting.durationHMS(nil) == "--:--:--")
        #expect(FlightFormatting.durationHMS(.nan) == "--:--:--")
        #expect(FlightFormatting.signedDurationHMS(7) == "+00:00:07")
        #expect(FlightFormatting.signedDurationHMS(-0.5) == "00:00:00")
    }

    @Test("Compact durations drop the hour until there is one", arguments: [
        (TimeInterval(0), false, "0:00"),
        (45, false, "0:45"),
        (272.9, false, "4:32"),
        (3725, false, "1:02:05"),
        (-65, false, "-1:05"),
        (7, true, "+0:07"),
        (-65, true, "-1:05"),
        (0.4, true, "0:00"),
    ])
    func compact(seconds: TimeInterval, signed: Bool, expected: String) {
        #expect(FlightFormatting.compactDuration(seconds, signed: signed) == expected)
    }

    @Test("Compact placeholder for nil and non-finite")
    func compactPlaceholder() {
        #expect(FlightFormatting.compactDuration(nil) == "--:--")
        #expect(FlightFormatting.compactDuration(.infinity, signed: true) == "--:--")
    }

    @Test("Speeds and distances in the pilot's unit with the app's symbols")
    func units() {
        #expect(FlightFormatting.speed(metersPerSecond: 0.514444 * 250, unit: .kts) == "250 kt")
        #expect(FlightFormatting.speed(metersPerSecond: nil, unit: .mph) == "--")
        #expect(FlightFormatting.distance(meters: 1852 * 12, unit: .nm) == "12.0 NM")
        #expect(FlightFormatting.distance(meters: nil, unit: .km) == "--")
    }

    @Test("Turn caption, minutes and seconds with the side")
    func turnCaption() {
        #expect(FlightFormatting.turnCaption(duration: 45, direction: .right) == "TURN 0:45 R")
        #expect(FlightFormatting.turnCaption(duration: 125.7, direction: .left) == "TURN 2:05 L")
        #expect(FlightFormatting.turnCaption(duration: nil, direction: .left) == nil)
        #expect(FlightFormatting.turnCaption(duration: 45, direction: nil) == nil)
    }
}
