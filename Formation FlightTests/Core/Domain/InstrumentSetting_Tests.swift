//
//  InstrumentSettingTests.swift
//

import Foundation
import Testing
@testable import Formation_Flight

@Suite("InstrumentSettingTests")
struct InstrumentSettingTests {
    // Helper JSON encoder/decoder with stable settings
    func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    func makeJSONDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    @Test
    func testEncodeDecodeRoundTrip() throws {

        let info = InFlightInfo.currentGroundSpeed

        let original = InstrumentSetting(type: info, isEnabled: true)
        let encoder = makeJSONEncoder()
        let data = try encoder.encode(original)

        let decoder = makeJSONDecoder()
        let decoded = try decoder.decode(InstrumentSetting.self, from: data)

        #expect(original == decoded, "Decoded object should be equal to the original")
    }

    @Test
    func testIdentifiableUsesTypeAsID() {
        let info = InFlightInfo.currentGroundSpeed

        let setting1 = InstrumentSetting(type: info, isEnabled: true)
        let setting2 = InstrumentSetting(type: info, isEnabled: false)

        #expect(setting1.id == setting2.id, "IDs should be equal because they use the same type")
        #expect(setting1 != setting2, "Settings with different isEnabled should not be equal")
    }

    @Test
    func testDecodingInvalidTypeStringThrows() throws {
        let json = """
        {
            "type": "invalid_type",
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let decoder = makeJSONDecoder()
        let error = try #require(throws: DecodingError.self, "Decoding should have thrown for an invalid type string") {
            try decoder.decode(InstrumentSetting.self, from: json)
        }
        guard case .dataCorrupted = error else {
            Issue.record("Expected dataCorrupted error, got \(error)")
            return
        }
    }

    @Test
    func testEncodingUsesRawStringForType() throws {
        let info = InFlightInfo.currentGroundSpeed

        let setting = InstrumentSetting(type: info, isEnabled: true)
        let encoder = makeJSONEncoder()
        let data = try encoder.encode(setting)

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let dict = try #require(jsonObject as? [String: Any], "Encoded JSON is not a dictionary")
        let typeValue = try #require(dict["type"] as? String, "'type' field is missing or not a string")

        #expect(typeValue == info.rawValue, "'type' field should be the raw string of InFlightInfo")
    }

    // MARK: - On-disk contract

    /// `InFlightInfo.rawValue` is the string `InstrumentSetting` writes to UserDefaults via
    /// `Settings.save(to:)`. These values are therefore an on-disk contract: renaming a case
    /// or editing a raw value makes `Settings.load(from:)` fail to decode every existing
    /// user's saved instrument layout and silently fall back to the defaults. Pin them.
    @Test("InFlightInfo raw values are stable (on-disk contract)")
    func testInFlightInfoRawValuesArePinned() {
        #expect(InFlightInfo.tot.rawValue == "ToT")
        #expect(InFlightInfo.totDrift.rawValue == "Drift")
        #expect(InFlightInfo.distance.rawValue == "Dist")
        #expect(InFlightInfo.bearing.rawValue == "Final Bearing")
        #expect(InFlightInfo.track.rawValue == "Track")
        #expect(InFlightInfo.currentGroundSpeed.rawValue == "Cur GS")
        #expect(InFlightInfo.requiredGroundSpeed.rawValue == "Req GS")
        #expect(InFlightInfo.expectedWindsDirection.rawValue == "Wind Direction")
        #expect(InFlightInfo.expectedWindsVelocity.rawValue == "Wind Speed")
        // Adding a case is fine (it gets a default); this just forces the list above to be revisited.
        #expect(InFlightInfo.allCases.count == 9)
    }
}
