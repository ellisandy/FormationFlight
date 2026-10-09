import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

/// `MeasurementFormatters` prints a locale-formatted number, a space (D-05), and the unit
/// symbol from `Settings` (D-09). The decimal separator depends on the test process locale;
/// `Formation Flight.xctestplan` pins `language: en` / `region: US` for that reason (T-05).
@Suite("MeasurementFormatters")
struct MeasurementFormattersTests {
    // MARK: - Speed Formatting
    @Test("Speed: nil returns placeholder")
    func speed_nil_returnsPlaceholder() async throws {
        let result = MeasurementFormatters.speedString(nil, unitPreference: .kts)
        #expect(result == "--")
    }

    @Test("Speed: knots use the aviation symbol kt")
    func speed_knots() async throws {
        let speed = Measurement(value: 250, unit: UnitSpeed.knots)
        #expect(MeasurementFormatters.speedString(speed, unitPreference: .kts) == "250 kt")
    }

    @Test("Speed: mph conversion")
    func speed_mph() async throws {
        // 100 m/s ≈ 223.693629 mph -> formatted with 0 fractional digits
        let speed = Measurement(value: 100, unit: UnitSpeed.metersPerSecond)
        #expect(MeasurementFormatters.speedString(speed, unitPreference: .mph) == "224 mph")
    }

    @Test("Speed: kph conversion")
    func speed_kph() async throws {
        // 55 mph ≈ 88.51392 km/h -> formatted with 0 fractional digits
        let speed = Measurement(value: 55, unit: UnitSpeed.milesPerHour)
        #expect(MeasurementFormatters.speedString(speed, unitPreference: .kph) == "89 km/h")
    }

    // MARK: - Distance Formatting
    @Test("Distance: nil returns placeholder")
    func distance_nil_returnsPlaceholder() async throws {
        let result = MeasurementFormatters.distanceString(nil, unitPreference: .nm)
        #expect(result == "--")
    }

    @Test("Distance: nautical miles use the aviation symbol NM")
    func distance_nauticalMiles() async throws {
        let distance = Measurement(value: 12, unit: UnitLength.nauticalMiles)
        #expect(MeasurementFormatters.distanceString(distance, unitPreference: .nm) == "12.0 NM")
    }

    @Test("Distance: miles conversion")
    func distance_miles() async throws {
        // 10 km ≈ 6.21371 mi -> formatted with 1 fractional digit
        let distance = Measurement(value: 10, unit: UnitLength.kilometers)
        #expect(MeasurementFormatters.distanceString(distance, unitPreference: .mi) == "6.2 mi")
    }

    @Test("Distance: kilometers conversion")
    func distance_kilometers() async throws {
        // 5 miles ≈ 8.04672 km -> formatted with 1 fractional digit
        let distance = Measurement(value: 5, unit: UnitLength.miles)
        #expect(MeasurementFormatters.distanceString(distance, unitPreference: .km) == "8.0 km")
    }

    // MARK: - Shared vocabulary (D-09)
    @Test("Settings and the flight screen use the same unit symbols")
    func symbolsMatchSettings() async throws {
        for unit in Settings.SpeedUnit.allCases {
            let shown = MeasurementFormatters.speedString(Measurement(value: 1, unit: UnitSpeed.knots), unitPreference: unit)
            #expect(shown.hasSuffix(" " + unit.symbol))
        }
        for unit in Settings.DistanceUnit.allCases {
            let shown = MeasurementFormatters.distanceString(Measurement(value: 1, unit: UnitLength.meters), unitPreference: unit)
            #expect(shown.hasSuffix(" " + unit.symbol))
        }
    }

    @Test("Persisted raw values are unchanged by the display symbols")
    func rawValuesArePinned() async throws {
        #expect(Settings.SpeedUnit.allCases.map(\.rawValue) == ["kts", "kph", "mph"])
        #expect(Settings.DistanceUnit.allCases.map(\.rawValue) == ["km", "mi", "nm"])
    }
}
