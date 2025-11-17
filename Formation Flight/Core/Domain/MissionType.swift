//
//  MissionType.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/14/25.
//

enum MissionType: String, Codable, CaseIterable, Sendable, RawRepresentable {
    case hackTime = "hack_time"
    case tot = "tot"
}
