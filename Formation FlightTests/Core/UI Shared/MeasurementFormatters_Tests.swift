import Foundation
import Testing
@testable import Formation_Flight

/// `MeasurementFormatters` uses a locale-sensitive `MeasurementFormatter` (medium unit style, D-05),
/// so the unit abbreviations and decimal separator below depend on the test process locale.
/// `Formation Flight.xctestplan` pins `language: en` / `region: US` for that reason (T-05);
/// for reference, de_DE renders 12 nautical miles as `12,0 sm`.
///
/// The conversion tests compare against a reference formatter configured identically to the
/// production one so a Foundation change to the abbreviation table does not fail them, while
/// the literal assertions in the knots and nautical-mile tests exist precisely to catch a
/// locale regression.
@Suite("MeasurementFormatters")
struct MeasurementFormattersTests {
    // MARK: - Reference formatters

    private func referenceString<U: Dimension>(_ measurement: Measurement<U>, fractionDigits: Int) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = fractionDigits
        formatter.numberFormatter.minimumFractionDigits = fractionDigits
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        return formatter.string(from: measurement)
    }

    // MARK: - Speed Formatting
    @Test("Speed: nil returns placeholder")
    func speed_nil_returnsPlaceholder() async throws {
        let result = MeasurementFormatters.speedString(nil, unitPreference: .kts)
        #expect(result == "--")
    }

    @Test("Speed: knots")
    func speed_knots() async throws {
        let speed = Measurement(value: 250, unit: UnitSpeed.knots)
        let result = MeasurementFormatters.speedString(speed, unitPreference: .kts)
        // Literal on purpose (locale canary): en_US medium style for knots is "kn" after a space.
        #expect(result == "250 kn")
    }

    @Test("Speed: mph conversion")
    func speed_mph() async throws {
        // 100 m/s ≈ 223.693629 mph -> formatted with 0 fractional digits
        let speed = Measurement(value: 100, unit: UnitSpeed.metersPerSecond)
        let result = MeasurementFormatters.speedString(speed, unitPreference: .mph)
        #expect(result.hasPrefix("224"))
        #expect(result == referenceString(speed.converted(to: .milesPerHour), fractionDigits: 0))
    }

    @Test("Speed: kph conversion")
    func speed_kph() async throws {
        // 55 mph ≈ 88.51392 km/h -> formatted with 0 fractional digits
        let speed = Measurement(value: 55, unit: UnitSpeed.milesPerHour)
        let result = MeasurementFormatters.speedString(speed, unitPreference: .kph)
        #expect(result.hasPrefix("89"))
        #expect(result == referenceString(speed.converted(to: .kilometersPerHour), fractionDigits: 0))
    }

    // MARK: - Distance Formatting
    @Test("Distance: nil returns placeholder")
    func distance_nil_returnsPlaceholder() async throws {
        let result = MeasurementFormatters.distanceString(nil, unitPreference: .nm)
        #expect(result == "--")
    }

    @Test("Distance: nautical miles")
    func distance_nauticalMiles() async throws {
        let distance = Measurement(value: 12, unit: UnitLength.nauticalMiles)
        let result = MeasurementFormatters.distanceString(distance, unitPreference: .nm)
        // Literal on purpose (locale canary): en_US medium style for nautical miles is "nmi",
        // decimal separator ".", a space before the unit.
        #expect(result == "12.0 nmi")
    }

    @Test("Distance: miles conversion")
    func distance_miles() async throws {
        // 10 km ≈ 6.21371 mi -> formatted with 1 fractional digit
        let distance = Measurement(value: 10, unit: UnitLength.kilometers)
        let result = MeasurementFormatters.distanceString(distance, unitPreference: .mi)
        #expect(result.hasPrefix("6"))
        #expect(result == referenceString(distance.converted(to: .miles), fractionDigits: 1))
    }

    @Test("Distance: kilometers conversion")
    func distance_kilometers() async throws {
        // 5 miles ≈ 8.04672 km -> formatted with 1 fractional digit
        let distance = Measurement(value: 5, unit: UnitLength.miles)
        let result = MeasurementFormatters.distanceString(distance, unitPreference: .km)
        #expect(result.hasPrefix("8"))
        #expect(result == referenceString(distance.converted(to: .kilometers), fractionDigits: 1))
    }
}
