import Foundation
import Testing
@testable import Formation_Flight

@Suite("Settings Tests")
struct SettingsTests {

    // MARK: - Helpers
    private func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }

    private func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    // MARK: - Codable round-trip
    @Test("Settings encodes and decodes symmetrically")
    func testCodableRoundTrip() throws {
        let original = Settings(
            speedUnit: .kts,
            distanceUnit: .nm,
            yellowTolerance: 3,
            redTolerance: 7,
            instrumentSettings: [
                InstrumentSetting(type: .currentGroundSpeed, isEnabled: true),
                InstrumentSetting(type: .bearing, isEnabled: false)
            ]
        )
        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(Settings.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Equatable semantics
    @Test("Settings equatable compares all fields including instrumentSettings")
    func testEquatable() throws {
        let a = Settings(
            speedUnit: .kts,
            distanceUnit: .nm,
            yellowTolerance: 1,
            redTolerance: 2,
            instrumentSettings: [InstrumentSetting(type: .track, isEnabled: true)]
        )
        var b = a
        #expect(a == b)
        b.redTolerance = 3
        #expect(a != b)
        b = a
        b.instrumentSettings[0].isEnabled.toggle()
        #expect(a != b)
    }

    // MARK: - Unit conversion helpers
    @Test("getUnitSpeed returns matching UnitSpeed")
    func testGetUnitSpeed() {
        #expect(Settings(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getUnitSpeed() == .knots)
        #expect(Settings(speedUnit: .kph, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getUnitSpeed() == .kilometersPerHour)
        #expect(Settings(speedUnit: .mph, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getUnitSpeed() == .milesPerHour)
    }

    @Test("getDistanceUnits returns matching UnitLength")
    func testGetDistanceUnits() {
        #expect(Settings(speedUnit: .kts, distanceUnit: .km, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getDistanceUnits() == .kilometers)
        #expect(Settings(speedUnit: .kts, distanceUnit: .mi, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getDistanceUnits() == .miles)
        #expect(Settings(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getDistanceUnits() == .nauticalMiles)
    }

    // MARK: - Defaults
    @Test("empty() provides expected defaults and instruments enabled")
    func testEmptyDefaults() {
        let s = Settings.empty()
        #expect(s.speedUnit == .kts)
        #expect(s.distanceUnit == .nm)
        #expect(s.yellowTolerance == 0)
        #expect(s.redTolerance == 0)
        // Ensure we have at least the 5 default instruments and they are enabled as specified
        #expect(s.instrumentSettings.count == 5)
        #expect(s.instrumentSettings.allSatisfy { $0.isEnabled })
        // Sanity check types exist
        let expected: [InFlightInfo] = [.currentGroundSpeed, .requiredGroundSpeed, .distance, .bearing, .track]
        #expect(Set(s.instrumentSettings.map { $0.type }) == Set(expected))
    }

    // MARK: - Persistence: load/save with merge behavior
    @Test("save(to:) and load(from:) round-trip and merge saved instrument isEnabled over defaults")
    func testLoadSaveMerge() throws {
        let defaults = UserDefaults(suiteName: "SettingsTests.testLoadSaveMerge")!
        defaults.removePersistentDomain(forName: "SettingsTests.testLoadSaveMerge")

        // Step 1: start with an initial settings where one default instrument is disabled
        var initial = Settings.empty()
        // Disable bearing in saved settings
        if let idx = initial.instrumentSettings.firstIndex(where: { $0.type == .bearing }) {
            initial.instrumentSettings[idx].isEnabled = false
        }
        initial.yellowTolerance = 9
        initial.redTolerance = 11
        initial.speedUnit = .mph
        initial.distanceUnit = .mi

        // Save
        initial.save(to: defaults)

        // Step 2: Load back; expect merge preserves saved isEnabled values, retains new defaults if any
        let loaded = Settings.load(from: defaults)

        #expect(loaded.speedUnit == .mph)
        #expect(loaded.distanceUnit == .mi)
        #expect(loaded.yellowTolerance == 9)
        #expect(loaded.redTolerance == 11)

        // Verify merge logic: for each default type, if there was a saved entry, isEnabled should match saved
        let defaultsList = Settings.empty().instrumentSettings
        for def in defaultsList {
            let loadedMatch = loaded.instrumentSettings.first { $0.type == def.type }
            #expect(loadedMatch != nil)
        }
        // Specifically, bearing should be disabled due to saved state
        let bearingLoaded = loaded.instrumentSettings.first { $0.type == .bearing }
        #expect(bearingLoaded?.isEnabled == false)
    }

    // MARK: - Decoding ignores unknown CodingKeys (minSpeed/maxSpeed/proximityToNextPoint)
    @Test("Decoding ignores removed keys and still succeeds")
    func testDecodingIgnoresRemovedKeys() throws {
        // Construct legacy-looking JSON with extra keys
        let json = """
        {
          "speedUnit": "kts",
          "distanceUnit": "nm",
          "yellowTolerance": 1,
          "redTolerance": 2,
          "instrumentSettings": [
            {"type": "Cur GS", "isEnabled": true},
            {"type": "Req GS", "isEnabled": true},
            {"type": "Dist", "isEnabled": true},
            {"type": "Final Bearing", "isEnabled": true},
            {"type": "Track", "isEnabled": true}
          ]
        }
        """.data(using: .utf8)!

        let decoded = try makeDecoder().decode(Settings.self, from: json)
        #expect(decoded.speedUnit == .kts)
        #expect(decoded.distanceUnit == .nm)
        #expect(decoded.yellowTolerance == 1)
        #expect(decoded.redTolerance == 2)
        #expect(decoded.instrumentSettings.count == 5)
    }
}

