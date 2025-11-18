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

        assert(original == decoded, "Decoded object should be equal to the original")
    }
    
    @Test
    func testIdentifiableUsesTypeAsID() {
        let info = InFlightInfo.currentGroundSpeed

        let setting1 = InstrumentSetting(type: info, isEnabled: true)
        let setting2 = InstrumentSetting(type: info, isEnabled: false)

        assert(setting1.id == setting2.id, "IDs should be equal because they use the same type")
        assert(setting1 != setting2, "Settings with different isEnabled should not be equal")
    }

    @Test
    func testDecodingInvalidTypeStringThrows() {
        let json = """
        {
            "type": "invalid_type",
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let decoder = makeJSONDecoder()
        do {
            _ = try decoder.decode(InstrumentSetting.self, from: json)
            assert(false, "Decoding should have thrown an error for invalid type string")
        } catch let error as DecodingError {
            switch error {
            case .dataCorrupted:
                // Expected error
                break
            default:
                assert(false, "Expected dataCorrupted error, got \(error)")
            }
        } catch {
            assert(false, "Expected DecodingError, got \(error)")
        }
    }
    
    @Test
    func testEncodingUsesRawStringForType() throws {
        let info = InFlightInfo.currentGroundSpeed

        let setting = InstrumentSetting(type: info, isEnabled: true)
        let encoder = makeJSONEncoder()
        let data = try encoder.encode(setting)

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let dict = jsonObject as? [String: Any] else {
            assert(false, "Encoded JSON is not a dictionary")
            return
        }

        guard let typeValue = dict["type"] as? String else {
            assert(false, "'type' field is missing or not a string")
            return
        }

        assert(typeValue == info.rawValue, "'type' field should be the raw string of InFlightInfo")
    }
}
