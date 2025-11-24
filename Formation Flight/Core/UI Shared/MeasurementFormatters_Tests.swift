import Foundation
import Testing
@testable import Formation_Flight

@Suite("MeasurementFormatters")
struct MeasurementFormattersTests {
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
        #expect(result == "250 kt")
    }

    @Test("Speed: mph conversion")
    func speed_mph() async throws {
        // 100 m/s ≈ 223.693629 mph -> formatted with 0 fractional digits
        let speed = Measurement(value: 100, unit: UnitSpeed.metersPerSecond)
        let result = MeasurementFormatters.speedString(speed, unitPreference: .mph)
        #expect(result == "224 mph")
    }

    @Test("Speed: kph conversion")
    func speed_kph() async throws {
        // 55 mph ≈ 88.51392 km/h -> formatted with 0 fractional digits
        let speed = Measurement(value: 55, unit: UnitSpeed.milesPerHour)
        let result = MeasurementFormatters.speedString(speed, unitPreference: .kph)
        #expect(result == "89 km/h")
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
        #expect(result == "12 nm")
    }

    @Test("Distance: miles conversion")
    func distance_miles() async throws {
        // 10 km ≈ 6.21371 mi -> formatted with 0 fractional digits
        let distance = Measurement(value: 10, unit: UnitLength.kilometers)
        let result = MeasurementFormatters.distanceString(distance, unitPreference: .mi)
        #expect(result == "6 mi")
    }

    @Test("Distance: kilometers conversion")
    func distance_kilometers() async throws {
        // 5 miles ≈ 8.04672 km -> formatted with 0 fractional digits
        let distance = Measurement(value: 5, unit: UnitLength.miles)
        let result = MeasurementFormatters.distanceString(distance, unitPreference: .km)
        #expect(result == "8 km")
    }
}
