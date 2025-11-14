//
//  InstrumentSetting.swift
//  Formation Flight
// 
//  Created by Jack Ellis on 2025-11-07.
//

import Foundation

struct InstrumentSetting: Identifiable, Codable, Equatable {
    let type: InFlightInfo
    var isEnabled: Bool
    var id: InFlightInfo { type }

    private enum CodingKeys: String, CodingKey {
        case type
        case isEnabled
    }

    init(type: InFlightInfo, isEnabled: Bool) {
        self.type = type
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode `type` as a raw string value
        let raw = try container.decode(String.self, forKey: .type)
        if let value = InFlightInfo(rawValue: raw) {
            self.type = value
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid InFlightInfo raw string: \(raw)"
            )
        }
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode `type` using its raw string value directly
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}
