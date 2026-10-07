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
        // Truncation is the deliberate app-wide policy (B-40, resolved): FlightViewModel floors
        // the clock and ETE to whole seconds and derives ETA from them, so every readout
        // truncates and Time + ETE always equals ETA on screen. 59.5 must stay "00:00:59",
        // never round up to "00:01:00".
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
        // B-10: bearings read as three digits on a compass card, so 13° renders as "013°".
        #expect(Formatting.angle(degrees: 12.6) == "013°")
        #expect(Formatting.angle(degrees: -12.4) == "--")
        #expect(Formatting.angle(nil) == "--")
        // Written as `-1.0` on purpose so it resolves to the `Double` overload: -1 is the
        // CoreLocation "unknown course" sentinel and must render as the placeholder.
        #expect(Formatting.angle(degrees: -1.0) == "--")
    }

    /// B-10: due north is a real bearing, not "unknown"; values are normalised into 0..<360
    /// after rounding so 359.6° wraps to "000°" rather than printing "360°"; the `Int`
    /// overload is in degrees (it used to build its `Measurement` in radians, so
    /// `angle(degrees: 90)` printed "5157°"); and every value is zero-padded to three digits.
    @Test
    func test_angle_zeroIsValidWrapsAndPads() {
        #expect(Formatting.angle(Measurement(value: 0, unit: .degrees)) == "000°")
        #expect(Formatting.angle(degrees: 0.0) == "000°")
        #expect(Formatting.angle(degrees: 0.4) == "000°")
        #expect(Formatting.angle(degrees: 359.6) == "000°")
        #expect(Formatting.angle(degrees: 359.4) == "359°")
        #expect(Formatting.angle(degrees: 360.0) == "000°")
        #expect(Formatting.angle(degrees: 270.4) == "270°")
        #expect(Formatting.angle(degrees: 7.0) == "007°")
        #expect(Formatting.angle(degrees: 90 as Int) == "090°")
        #expect(Formatting.angle(degrees: 0 as Int) == "000°")
        #expect(Formatting.angle(degrees: 359 as Int) == "359°")
        let optionalZero: Double? = 0
        #expect(Formatting.angle(degrees: optionalZero) == "000°")
        let optionalSentinel: Double? = -1
        #expect(Formatting.angle(degrees: optionalSentinel) == "--")
    }

    /// B-34: non-finite or absurdly large input must not reach `Int(_:)`, which traps (and
    /// takes the whole test runner down with it). Every case here used to trap, so they are
    /// deliberately isolated in their own test function: if this function disappears from the
    /// results instead of failing, the guard has regressed.
    ///
    /// Only the guards are under test; the angle semantics are covered by
    /// `test_angle_zeroIsValidWrapsAndPads`.
    @Test
    func test_angle_nonFiniteInputsReturnPlaceholder() {
        #expect(Formatting.angle(Measurement(value: .nan, unit: .degrees)) == "--")
        #expect(Formatting.angle(Measurement(value: .infinity, unit: .degrees)) == "--")
        // Non-optional Double overload routes through the Measurement path.
        #expect(Formatting.angle(degrees: Double.infinity) == "--")
        #expect(Formatting.angle(degrees: Double.nan) == "--")
        // The `Double?` overload has its own `Int(value.rounded())` and must be guarded too.
        let optionalInfinity: Double? = .infinity
        let optionalNaN: Double? = .nan
        #expect(Formatting.angle(degrees: optionalInfinity) == "--")
        #expect(Formatting.angle(degrees: optionalNaN) == "--")
        // Finite but beyond Int range: `Int(1e300)` traps just like `Int(.infinity)`.
        #expect(Formatting.angle(degrees: 1e300) == "--")
        let optionalHuge: Double? = 1e300
        #expect(Formatting.angle(degrees: optionalHuge) == "--")
    }

    /// B-34: a coordinate with a non-finite component is treated like a missing coordinate
    /// and yields the same empty-string placeholders, instead of trapping in `Int(absValue)`.
    @Test
    func test_dms_nonFiniteCoordinateReturnsPlaceholders() {
        let nanLat = Formatting.dms(from: CLLocationCoordinate2D(latitude: .nan, longitude: 0))
        #expect(nanLat.lat == "")
        #expect(nanLat.lon == "")

        let infLon = Formatting.dms(from: CLLocationCoordinate2D(latitude: 0, longitude: .infinity))
        #expect(infLon.lat == "")
        #expect(infLon.lon == "")

        let hugeLat = Formatting.dms(from: CLLocationCoordinate2D(latitude: 1e300, longitude: 0))
        #expect(hugeLat.lat == "")
        #expect(hugeLat.lon == "")
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
    @Test
    func test_dms_southEastHemispheres() {
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let (latStr, lonStr) = Formatting.dms(from: coord)
        #expect(latStr == "S 33 52.13")
        #expect(lonStr == "E 151 12.56")
    }

    /// B-10: minutes below 10 are zero-padded to two integer digits so the column lines up
    /// ("05.00", not "5.00"). 0.0833 * 60 = 4.998 -> "05.00" on both axes.
    @Test
    func test_dms_padsMinutesBelowTen() {
        let coord = CLLocationCoordinate2D(latitude: 37.0833, longitude: -122.0833)
        let (latStr, lonStr) = Formatting.dms(from: coord)
        #expect(latStr == "N 37 05.00")
        #expect(lonStr == "W 122 05.00")

        // Whole degrees: zero minutes still print two digits.
        let whole = Formatting.dms(from: CLLocationCoordinate2D(latitude: 45, longitude: -90))
        #expect(whole.lat == "N 45 00.00")
        #expect(whole.lon == "W 90 00.00")
    }
}
