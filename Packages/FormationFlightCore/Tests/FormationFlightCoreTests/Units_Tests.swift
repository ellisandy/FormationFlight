import Foundation
import Testing
@testable import FormationFlightCore

/// The display units and mission type are persisted (UserDefaults, SwiftData) and sent to the
/// watch, so their encodings are pinned here.
@Suite("Units and MissionType")
struct UnitsTests {
    @Test("Raw values are stable (on-disk contract)")
    func rawValues() {
        #expect(SpeedUnit.allCases.map(\.rawValue) == ["kts", "kph", "mph"])
        #expect(DistanceUnit.allCases.map(\.rawValue) == ["km", "mi", "nm"])
        #expect(MissionType.allCases.map(\.rawValue) == ["hack_time", "tot"])
    }

    @Test("Codable shape is the bare raw string, as Settings has always stored it")
    func codableShape() throws {
        #expect(String(data: try JSONEncoder().encode(SpeedUnit.mph), encoding: .utf8) == #""mph""#)
        #expect(try JSONDecoder().decode(DistanceUnit.self, from: Data(#""nm""#.utf8)) == .nm)
        #expect(try JSONDecoder().decode(MissionType.self, from: Data(#""hack_time""#.utf8)) == .hackTime)
    }

    @Test("Symbols and Foundation units")
    func symbolsAndUnits() {
        #expect(SpeedUnit.allCases.map(\.symbol) == ["kt", "km/h", "mph"])
        #expect(DistanceUnit.allCases.map(\.symbol) == ["km", "mi", "NM"])
        #expect(SpeedUnit.allCases.map(\.unitSpeed) == [.knots, .kilometersPerHour, .milesPerHour])
        #expect(DistanceUnit.allCases.map(\.unitLength) == [.kilometers, .miles, .nauticalMiles])
    }

    @Test("The payload version is set")
    func payloadVersion() {
        #expect(CorePayload.version >= 1)
    }
}
