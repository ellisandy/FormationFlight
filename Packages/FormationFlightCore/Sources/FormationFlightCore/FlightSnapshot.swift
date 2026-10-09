//
//  FlightSnapshot.swift
//  FormationFlightCore
//
//  The single message the phone sends to its mirrors (the Apple Watch companion and the Live
//  Activity). The phone is the GPS source and the source of truth; mirrors only render.
//

import Foundation

/// Everything a mirror needs to render the flight screen, as *inputs*, not derived readouts.
///
/// The phone sends one on every 1 Hz timing tick. A receiver recomputes Time / ETE / ETA / Δ
/// on its own clock with `timing(at:)`, so it keeps ticking smoothly between messages and
/// shows exactly what the phone's `TimingEngine` would show at that instant. When the phone
/// stops sending (backgrounded, out of range) or its fix goes stale, `isStale(at:)` turns
/// true and the mirror shows its STALE state instead of numbers counting down on old data.
public struct FlightSnapshot: Codable, Sendable, Equatable {
    /// `CorePayload.version` at encode time; checked by `init(data:)`.
    public var version: Int
    /// Phone clock when the snapshot was built.
    public var sentAt: Date

    // MARK: Mission
    public var missionName: String
    public var missionType: MissionType
    /// Nil for a hack mission until Hack! is pressed (B-23), or a ToT mission with no date.
    public var tot: Date?
    /// Hack duration, seconds, for a hack mission.
    public var hackTime: TimeInterval?
    /// A hack mission whose Hack! has not been pressed yet: there is no ToT to count to.
    public var isHackPending: Bool

    // MARK: Latest fix
    /// Phone clock when the latest fix was received, the time staleness is measured from
    /// (B-07); nil before the first fix.
    public var fixTime: Date?
    /// Distance to the target, metres.
    public var distance: Double?
    /// Ground speed, metres per second; nil when unknown or already blanked as stale.
    public var groundSpeed: Double?
    /// True track, degrees; nil when unknown or stale. Same reference as `bearing` (B-26).
    public var track: Double?
    /// True bearing to the target, degrees.
    public var bearing: Double?
    /// The orbit in progress detected from the track rate (B-25), nil while straight.
    public var turnDirection: TurnToTarget.Direction?
    /// The phone had already judged the fix stale when it sent this.
    public var isFixStale: Bool

    // MARK: Pilot settings
    public var yellowTolerance: Int
    public var redTolerance: Int
    public var speedUnit: SpeedUnit
    public var distanceUnit: DistanceUnit

    /// The flight screen was closed (End Flight). The last snapshot a mirror receives.
    public var isEnded: Bool

    public init(version: Int = CorePayload.version,
                sentAt: Date,
                missionName: String,
                missionType: MissionType,
                tot: Date?,
                hackTime: TimeInterval?,
                isHackPending: Bool,
                fixTime: Date?,
                distance: Double?,
                groundSpeed: Double?,
                track: Double?,
                bearing: Double?,
                turnDirection: TurnToTarget.Direction?,
                isFixStale: Bool,
                yellowTolerance: Int,
                redTolerance: Int,
                speedUnit: SpeedUnit,
                distanceUnit: DistanceUnit,
                isEnded: Bool = false) {
        self.version = version
        self.sentAt = sentAt
        self.missionName = missionName
        self.missionType = missionType
        self.tot = tot
        self.hackTime = hackTime
        self.isHackPending = isHackPending
        self.fixTime = fixTime
        self.distance = distance
        self.groundSpeed = groundSpeed
        self.track = track
        self.bearing = bearing
        self.turnDirection = turnDirection
        self.isFixStale = isFixStale
        self.yellowTolerance = yellowTolerance
        self.redTolerance = redTolerance
        self.speedUnit = speedUnit
        self.distanceUnit = distanceUnit
        self.isEnded = isEnded
    }

    // MARK: - Receiver-side derivations

    /// Whether the mirror should show its STALE state at `now` (receiver clock).
    ///
    /// True when the phone said the fix was stale, when the fix has aged past
    /// `TimingEngine.staleFixThreshold` since (the phone would blank it on its next tick), or
    /// when no new snapshot has arrived for longer than the threshold: the phone has been
    /// backgrounded or gone out of range, so nothing on screen is live any more. Exactly at the
    /// threshold is still fresh, matching the phone's own `>` rule.
    public func isStale(at now: Date) -> Bool {
        isFixStale
            || TimingEngine.isFixStale(lastFix: fixTime, now: now)
            || now.timeIntervalSince(sentAt) > TimingEngine.staleFixThreshold
    }

    /// The readouts at `now` on the receiver's clock, from this snapshot's inputs.
    ///
    /// When stale (see `isStale(at:)`) the speed, track and orbit direction are dropped before
    /// computing, as the phone does (B-07): ETE / ETA / Δ fall to placeholders while the ToT
    /// countdown (`timeToToT`) and the distance-based required speed keep going.
    public func timing(at now: Date) -> TimingEngine.Output {
        let stale = isStale(at: now)
        return TimingEngine.compute(TimingEngine.Input(
            now: now,
            tot: tot,
            distance: distance,
            groundSpeed: stale ? nil : groundSpeed,
            track: stale ? nil : track,
            bearing: bearing,
            preferredTurnDirection: stale ? nil : turnDirection,
            yellowTolerance: yellowTolerance,
            redTolerance: redTolerance
        ))
    }

    // MARK: - Codec
    // On the WatchConnectivity wire a snapshot travels inside `WatchMessage` (F-02), which
    // carries the dictionary key; these encode the snapshot on its own.

    public enum CodecError: Error, Equatable {
        /// The payload was written by a build with a different `payloadVersion`.
        case unsupportedVersion(found: Int, expected: Int)
    }

    /// JSON, with dates as seconds since the reference date so they round-trip exactly.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(self)
    }

    /// Decodes a payload from `encoded()`. The version is read first, on its own, so a
    /// payload from an incompatible build fails with `CodecError.unsupportedVersion` rather
    /// than a confusing missing-key error (or, worse, a silent misread).
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let probe = try decoder.decode(VersionProbe.self, from: data)
        guard probe.version == CorePayload.version else {
            throw CodecError.unsupportedVersion(found: probe.version, expected: CorePayload.version)
        }
        self = try decoder.decode(FlightSnapshot.self, from: data)
    }

    private struct VersionProbe: Decodable {
        let version: Int
    }
}
