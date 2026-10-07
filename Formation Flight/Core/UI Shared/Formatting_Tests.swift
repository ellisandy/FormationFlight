import Testing
import Foundation
import CoreLocation
@testable import Formation_Flight

@Suite("FormattingTests")
final class FormattingTests {
    
    @Test
    func test_timeHHmmss() throws {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.calendar = calendar
        comps.year = 2023
        comps.month = 1
        comps.day = 1
        comps.hour = 13
        comps.minute = 37
        comps.second = 42
        let date = try #require(comps.date, "Failed to create date from components")

        #expect(Formatting.timeHHmmss(date) == "13:37:42")
        #expect(Formatting.timeHHmmss(nil) == "--:--:--")
    }

    @Test
    func test_durationHMS() {
        #expect(Formatting.durationHMS(0) == "00:00:00")
        // Documents current truncation behaviour. B-40 (round instead of truncate) is still
        // open; when it lands this expectation becomes "00:01:00".
        #expect(Formatting.durationHMS(59.5) == "00:00:59")
        #expect(Formatting.durationHMS(61.2) == "00:01:01")
        #expect(Formatting.durationHMS(nil) == "--:--:--")
    }

    /// B-01: negative durations must render as a leading `-` followed by the
    /// zero-padded magnitude, not as per-component negative numbers (`00:-1:-5`).
    /// The sign follows the sign of the input, so a sub-second negative value
    /// such as `-0.5` renders as `-00:00:00` (magnitude truncates to zero).
    @Test
    func test_durationHMS_negativeValues() {
        #expect(Formatting.durationHMS(-65) == "-00:01:05")
        #expect(Formatting.durationHMS(-3661) == "-01:01:01")
        #expect(Formatting.durationHMS(-0.5) == "-00:00:00")
    }

    /// B-01: non-finite input must not trap in `Int(_:)`; it should fall back to
    /// the same placeholder used for `nil`.
    @Test
    func test_durationHMS_nonFinite() {
        #expect(Formatting.durationHMS(.nan) == "--:--:--")
        #expect(Formatting.durationHMS(.infinity) == "--:--:--")
        #expect(Formatting.durationHMS(-.infinity) == "--:--:--")
    }

    /// B-01: the Δ readout always carries an explicit sign so early vs. late is unambiguous.
    @Test
    func test_signedDurationHMS() {
        #expect(Formatting.signedDurationHMS(7) == "+00:00:07")
        #expect(Formatting.signedDurationHMS(-65) == "-00:01:05")
        #expect(Formatting.signedDurationHMS(-3661) == "-01:01:01")
        #expect(Formatting.signedDurationHMS(0) == "+00:00:00")
        #expect(Formatting.signedDurationHMS(nil) == "--:--:--")
    }

    @Test
    func test_signedDurationHMS_nonFinite() {
        #expect(Formatting.signedDurationHMS(.nan) == "--:--:--")
        #expect(Formatting.signedDurationHMS(.infinity) == "--:--:--")
        #expect(Formatting.signedDurationHMS(-.infinity) == "--:--:--")
    }

    @Test
    func test_angle() {
        #expect(Formatting.angle(degrees: 12.6) == "13°")
        #expect(Formatting.angle(degrees: -12.4) == "--")
        #expect(Formatting.angle(nil) == "--")
        // Written as `-1.0` on purpose: an integer literal resolves to the `Int` overload,
        // which (B-10, still open) builds its Measurement in RADIANS and only happened to
        // return "--" for -1. The Double sentinel path is the one this test is about.
        #expect(Formatting.angle(degrees: -1.0) == "--")
    }

    @Test
    func test_dms() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let (latStr, lonStr) = Formatting.dms(from: coord)
        #expect(latStr == "N 37 46.49")
        #expect(lonStr == "W 122 25.16")

        let nilCoord: CLLocationCoordinate2D? = nil
        let (nilLat, nilLon) = Formatting.dms(from: nilCoord)
        #expect(nilLat == "")
        #expect(nilLon == "")
    }

    /// Southern and eastern hemispheres (Sydney). Minutes: 0.8688 * 60 = 52.128 -> "52.13",
    /// 0.2093 * 60 = 12.558 -> "12.56".
    ///
    /// Both minute values are >= 10 on purpose: zero-padding of minutes below 10 is not
    /// asserted anywhere because the `%02.2f` format in `dms` does not pad (B-10, open).
    @Test
    func test_dms_southEastHemispheres() {
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let (latStr, lonStr) = Formatting.dms(from: coord)
        #expect(latStr == "S 33 52.13")
        #expect(lonStr == "E 151 12.56")
    }
}
