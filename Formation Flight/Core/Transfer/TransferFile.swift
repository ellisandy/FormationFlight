import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import FormationFlightCore

extension UTType {
    // The payload is JSON internally, but these are app-owned document types rather than
    // public JSON. Declaring JSON conformance makes Messages preview the source text instead
    // of routing a tap to Formation Flight.
    static let formationFlight = UTType(exportedAs: "com.jackellis.formationflight.flight", conformingTo: .data)
    static let formationPreferences = UTType(exportedAs: "com.jackellis.formationflight.preferences", conformingTo: .data)
}

enum TransferFileError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidFlight
    case unexpectedFileType

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            String(localized: "This file was created by an unsupported version of Formation Flight.")
        case .invalidFlight:
            String(localized: "The shared flight is incomplete or invalid.")
        case .unexpectedFileType:
            String(localized: "Formation Flight cannot import this file type.")
        }
    }
}

struct FlightTransferPayload: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let formatVersion: Int
    let missionName: String
    let missionType: MissionType
    let missionDate: Date?
    let targetLatitude: Double
    let targetLongitude: Double
    let hackTime: TimeInterval?

    init(flight: Flight) throws {
        guard let target = flight.target else {
            throw TransferFileError.invalidFlight
        }
        formatVersion = Self.currentVersion
        missionName = flight.missionName
        missionType = flight.missionType
        missionDate = flight.missionDate
        targetLatitude = target.latitude
        targetLongitude = target.longitude
        hackTime = flight.hackTime
    }

    func makeFlight() throws -> Flight {
        guard formatVersion == Self.currentVersion else {
            throw TransferFileError.unsupportedVersion(formatVersion)
        }
        guard !missionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              targetLatitude.isFinite,
              (-90.0...90.0).contains(targetLatitude),
              targetLongitude.isFinite,
              (-180.0...180.0).contains(targetLongitude) else {
            throw TransferFileError.invalidFlight
        }
        switch missionType {
        case .tot:
            guard missionDate != nil else { throw TransferFileError.invalidFlight }
        case .hackTime:
            guard let hackTime, hackTime.isFinite, hackTime > 0 else {
                throw TransferFileError.invalidFlight
            }
        }
        return Flight(
            missionName: missionName,
            missionType: missionType,
            missionDate: missionType == .tot ? missionDate : nil,
            target: Target(longitude: targetLongitude, latitude: targetLatitude),
            hackTime: missionType == .hackTime ? hackTime : nil
        )
    }
}

struct PreferencesTransferPayload: Codable, Equatable {
    static let currentVersion = 1

    let formatVersion: Int
    let settings: Settings

    init(settings: Settings) {
        formatVersion = Self.currentVersion
        self.settings = settings.validated()
    }

    func importedSettings() throws -> Settings {
        guard formatVersion == Self.currentVersion else {
            throw TransferFileError.unsupportedVersion(formatVersion)
        }
        return settings.validated()
    }
}

struct FlightShareFile: Transferable {
    let data: Data
    let filename: String

    init(flight: Flight) throws {
        data = try TransferFileCodec.encoder.encode(FlightTransferPayload(flight: flight))
        filename = TransferFileCodec.safeFilename(flight.missionName, fallback: "Flight") + ".formationflight"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .formationFlight) { item in
            SentTransferredFile(try TransferFileCodec.temporaryFile(data: item.data, filename: item.filename))
        }
    }
}

struct PreferencesShareFile: Transferable {
    let data: Data
    let filename = "Formation Flight Preferences.formationpreferences"

    init(settings: Settings) throws {
        data = try TransferFileCodec.encoder.encode(PreferencesTransferPayload(settings: settings))
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .formationPreferences) { item in
            SentTransferredFile(try TransferFileCodec.temporaryFile(data: item.data, filename: item.filename))
        }
    }
}

enum ImportedTransferFile {
    case flight(FlightTransferPayload)
    case preferences(PreferencesTransferPayload)

    static func read(from url: URL) throws -> ImportedTransferFile {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        switch url.pathExtension.lowercased() {
        case "formationflight":
            return .flight(try TransferFileCodec.decoder.decode(FlightTransferPayload.self, from: data))
        case "formationpreferences":
            return .preferences(try TransferFileCodec.decoder.decode(PreferencesTransferPayload.self, from: data))
        default:
            throw TransferFileError.unexpectedFileType
        }
    }
}

enum TransferFileCodec {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func safeFilename(_ name: String, fallback: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    static func temporaryFile(data: Data, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
