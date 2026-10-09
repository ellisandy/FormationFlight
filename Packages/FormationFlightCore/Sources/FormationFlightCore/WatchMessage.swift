//
//  WatchMessage.swift
//  FormationFlightCore
//
//  F-02: the WatchConnectivity wire format between the phone and the Apple Watch companion.
//  Pure Foundation, so both ends' encoding and decoding are tested with `swift test`; the
//  WatchConnectivity calls themselves stay in the apps behind thin seams.
//

import Foundation

/// One phone-to-watch message: the flight's inputs, or a cue.
///
/// Inputs, not strings: the watch recomputes the readouts from the snapshot on its own clock
/// and renders the cue's text and haptic from the event, in its own language.
///
/// On the wire every message is a single JSON `Data` under `payloadKey`, in the dictionary
/// `WCSession.sendMessage(_:replyHandler:errorHandler:)` and `updateApplicationContext(_:)`
/// take. One key and one blob, rather than a key per field, so the version check covers
/// everything and a newer field can never be half-read by an older build.
public enum WatchMessage: Equatable, Sendable {
    /// The latest flight state. Sent every 1 Hz tick when the watch is reachable, and as the
    /// application context (see `WatchSendPolicy`) so a watch app opened mid-flight catches up.
    case snapshot(FlightSnapshot)
    /// A cue as the phone's banner showed it (F-01). `emittedAt` is the phone clock of the tick
    /// that produced it, so the watch can drop a cue that arrives too late to be useful.
    case callout(Callout, emittedAt: Date)

    /// The single dictionary key the encoded message travels under.
    public static let payloadKey = "ffWatchMessage"

    public enum CodecError: Error, Equatable {
        /// No `Data` under `payloadKey`: not one of ours (or an empty application context).
        case missingPayload
        /// Written by a build with a different `CorePayload.version`.
        case unsupportedVersion(found: Int, expected: Int)
        /// The right version but neither a snapshot nor a callout.
        case malformed
    }

    // MARK: Data

    /// JSON, dates as seconds since the reference date so they round-trip exactly.
    public func encoded() throws -> Data {
        let envelope: Envelope
        switch self {
        case .snapshot(let snapshot):
            envelope = Envelope(version: CorePayload.version, snapshot: snapshot)
        case .callout(let callout, let emittedAt):
            envelope = Envelope(version: CorePayload.version, callout: callout, emittedAt: emittedAt)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(envelope)
    }

    /// Decodes `encoded()`. The version is read on its own first, so a message from an
    /// incompatible build fails with `unsupportedVersion` instead of a misread. The snapshot
    /// inside carries its own version too, checked the same way.
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let probe = try decoder.decode(VersionProbe.self, from: data)
        guard probe.version == CorePayload.version else {
            throw CodecError.unsupportedVersion(found: probe.version, expected: CorePayload.version)
        }
        let envelope = try decoder.decode(Envelope.self, from: data)
        if let snapshot = envelope.snapshot {
            guard snapshot.version == CorePayload.version else {
                throw CodecError.unsupportedVersion(found: snapshot.version, expected: CorePayload.version)
            }
            self = .snapshot(snapshot)
        } else if let callout = envelope.callout, let emittedAt = envelope.emittedAt {
            self = .callout(callout, emittedAt: emittedAt)
        } else {
            throw CodecError.malformed
        }
    }

    // MARK: WatchConnectivity dictionaries

    /// `[payloadKey: encoded()]`, ready for `sendMessage` or `updateApplicationContext`.
    public func transferDictionary() throws -> [String: Any] {
        [Self.payloadKey: try encoded()]
    }

    /// Parses a received message or application context.
    public init(transferDictionary dictionary: [String: Any]) throws {
        guard let data = dictionary[Self.payloadKey] as? Data else {
            throw CodecError.missingPayload
        }
        try self.init(data: data)
    }

    // MARK: Private

    /// The JSON shape: exactly one of `snapshot` or `callout` (with `emittedAt`) is set.
    private struct Envelope: Codable {
        var version: Int
        var snapshot: FlightSnapshot?
        var callout: Callout?
        var emittedAt: Date?
    }

    private struct VersionProbe: Decodable {
        let version: Int
    }
}
