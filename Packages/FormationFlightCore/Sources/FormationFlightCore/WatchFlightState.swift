//
//  WatchFlightState.swift
//  FormationFlightCore
//
//  F-02: what the Apple Watch companion knows about the flight, and the rules for what it
//  shows and when it taps the wrist. Pure value logic so it is tested with `swift test`; the
//  watch app's model only feeds it messages and the watch clock.
//

import Foundation

/// The watch's view of the phone's flight: the newest snapshot, the latest cue, and the
/// decisions that depend on them.
///
/// Every time-dependent answer takes `now` (the watch clock). The phone's `sentAt` and
/// `emittedAt` are compared with it directly: both clocks are network-synced, and the
/// thresholds involved (seconds) are far above their usual skew.
public struct WatchFlightState: Equatable, Sendable {
    /// What the watch shows.
    public enum Phase: Equatable, Sendable {
        /// No flight: "Start a flight on your iPhone".
        case idle
        /// A hack mission whose Hack! has not been pressed.
        case awaitingHack
        /// Live numbers.
        case active
        /// Nothing on screen can be trusted as live (see `StaleReason`).
        case stale(StaleReason)
        /// The phone ended the flight; shown for `endedDisplayDuration`, then `idle`.
        case ended
    }

    public enum StaleReason: Equatable, Sendable {
        /// No snapshot for longer than `TimingEngine.staleFixThreshold`: the phone app has been
        /// backgrounded, locked, or is out of range. `since` is the last snapshot's `sentAt`.
        case phoneSilent(since: Date)
        /// The phone is talking but its GPS fix is stale (B-07). `since` is the last fix.
        case fixLost(since: Date?)
    }

    /// How long "Flight ended" stays before the watch returns to idle.
    public static let endedDisplayDuration: TimeInterval = 10

    /// After this long with no word from the phone the flight is treated as abandoned (the
    /// phone app was killed or died) and the watch returns to idle rather than show STALE
    /// for ever. Half an hour is far beyond any backgrounding a pilot means to come back from.
    public static let abandonedAfter: TimeInterval = 30 * 60

    /// A cue older than this when it reaches the watch is dropped, banner and haptic both: a
    /// tap about a countdown mark or turn point already past would be wrong, not just late.
    public static let maxCalloutAge: TimeInterval = 3

    /// How long a cue's banner stays on the watch, as on the phone (F-01).
    public static let calloutBannerDuration: TimeInterval = 4

    /// The newest snapshot received.
    public private(set) var snapshot: FlightSnapshot?
    /// The latest accepted cue, with the watch time it arrived (for the banner).
    public private(set) var callout: Callout?
    public private(set) var calloutReceivedAt: Date?
    /// Phone time of the latest accepted cue: anything at or before it is a duplicate or out of
    /// order. The phone emits at most one cue per tick, so `emittedAt` identifies a cue.
    private var lastCalloutEmittedAt: Date?

    public init() {}

    // MARK: Receiving

    /// Takes `snapshot` if it is newer than the one held. Returns whether it was taken.
    ///
    /// The same snapshot can arrive twice (by message and as the application context), and the
    /// context can land after messages that followed it, so only a strictly later `sentAt`
    /// wins. A new flight after an ended one is simply a later snapshot.
    @discardableResult
    public mutating func receive(_ snapshot: FlightSnapshot) -> Bool {
        if let current = self.snapshot, snapshot.sentAt <= current.sentAt { return false }
        self.snapshot = snapshot
        if snapshot.isEnded {
            callout = nil
            calloutReceivedAt = nil
        }
        return true
    }

    /// Takes a cue, returning the haptic to play now, or nil to stay silent.
    ///
    /// A cue is taken (banner and haptic) only when:
    /// - there is a flight that has not ended and the phone is still talking (its last snapshot
    ///   is within `TimingEngine.staleFixThreshold`). A stale *fix* does not silence it: "GPS
    ///   lost." arrives with exactly that snapshot and is the cue that most needs the tap;
    /// - it is not older than `maxCalloutAge` on the watch clock;
    /// - it is not a duplicate or out of order (`emittedAt` after the last cue taken).
    public mutating func receive(_ callout: Callout, emittedAt: Date, at now: Date) -> CueHaptic? {
        guard let snapshot, !snapshot.isEnded,
              !Self.isPhoneSilent(snapshot, at: now),
              now.timeIntervalSince(emittedAt) <= Self.maxCalloutAge
        else { return nil }
        if let last = lastCalloutEmittedAt, emittedAt <= last { return nil }
        lastCalloutEmittedAt = emittedAt
        self.callout = callout
        calloutReceivedAt = now
        return callout.haptic
    }

    /// Feeds a decoded message; the haptic to play, if any.
    public mutating func receive(_ message: WatchMessage, at now: Date) -> CueHaptic? {
        switch message {
        case .snapshot(let snapshot):
            receive(snapshot)
            return nil
        case .callout(let callout, let emittedAt):
            return receive(callout, emittedAt: emittedAt, at: now)
        }
    }

    // MARK: Deriving

    public func phase(at now: Date) -> Phase {
        guard let snapshot else { return .idle }
        let age = now.timeIntervalSince(snapshot.sentAt)
        if snapshot.isEnded {
            return age < Self.endedDisplayDuration ? .ended : .idle
        }
        if age > Self.abandonedAfter { return .idle }
        if Self.isPhoneSilent(snapshot, at: now) { return .stale(.phoneSilent(since: snapshot.sentAt)) }
        if snapshot.isStale(at: now) { return .stale(.fixLost(since: snapshot.fixTime)) }
        if snapshot.isHackPending { return .awaitingHack }
        return .active
    }

    /// The readouts at `now`, computed on the watch clock from the latest inputs (nil with no
    /// flight). When stale, speed-derived values are already blank (`FlightSnapshot.timing`).
    public func timing(at now: Date) -> TimingEngine.Output? {
        snapshot?.timing(at: now)
    }

    /// The cue to show as a banner at `now`, if one arrived within `calloutBannerDuration`
    /// and the flight is still on screen.
    public func banner(at now: Date) -> Callout? {
        guard let callout, let calloutReceivedAt,
              now.timeIntervalSince(calloutReceivedAt) < Self.calloutBannerDuration
        else { return nil }
        switch phase(at: now) {
        case .idle, .ended: return nil
        case .awaitingHack, .active, .stale: return callout
        }
    }

    private static func isPhoneSilent(_ snapshot: FlightSnapshot, at now: Date) -> Bool {
        now.timeIntervalSince(snapshot.sentAt) > TimingEngine.staleFixThreshold
    }
}
