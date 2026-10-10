//
//  FlightActivity.swift
//  FormationFlightCore
//
//  F-02: the Live Activity (lock screen, Dynamic Island, Apple Watch Smart Stack). The widget
//  extension cannot run the timing logic on a clock of its own: it only redraws when the app
//  sends new content. So the content is the *rendered* readouts at send time, with the ToT as
//  an absolute date the widget counts down to with a self-updating timer text.
//
//  The content type and its update policy live outside the ActivityKit guard so they build and
//  test with `swift test` on macOS; only the `ActivityAttributes` conformance is iOS-only.
//

import Foundation

/// What the Live Activity shows, as of `updatedAt`. This is the activity's `ContentState`.
///
/// Codable and Hashable as ActivityKit requires. The synthesized encoding travels between the
/// app and its widget extension (built together), so it is versioned with the app, not with
/// `CorePayload.version`.
public struct FlightActivityContent: Codable, Hashable, Sendable {
    /// Time on target; the widget counts down to it with a timer text, so the countdown keeps
    /// going between updates and stays right even when the rest goes STALE (it is an absolute
    /// time, not a measured one). Nil while a hack is pending or with no ToT.
    public var tot: Date?
    /// Estimated time of arrival, whole seconds (B-40); nil without a usable fix.
    public var eta: Date?
    /// ETA minus ToT in whole seconds (B-46), positive late; nil when there is nothing to judge.
    public var delta: Int?
    public var status: TimingStatus
    /// A hack mission whose Hack! has not been pressed: show "AWAITING HACK", not a countdown.
    public var isHackPending: Bool
    /// The latest cue (F-01), kept for `LiveActivityPolicy.cueDisplayDuration` so a glance at
    /// the lock screen or wrist shows what was just called out.
    public var cue: Callout.Event?
    /// Phone clock when `cue` was emitted.
    public var cueAt: Date?
    /// Phone clock when this content was built.
    public var updatedAt: Date
    /// The phone itself judged the fix stale (B-07): Δ and ETA are already blank, and the widget
    /// shows its STALE treatment even though the content is fresh.
    public var isFixStale: Bool

    public init(tot: Date?,
                eta: Date?,
                delta: Int?,
                status: TimingStatus,
                isHackPending: Bool,
                cue: Callout.Event? = nil,
                cueAt: Date? = nil,
                updatedAt: Date,
                isFixStale: Bool) {
        self.tot = tot
        self.eta = eta
        self.delta = delta
        self.status = status
        self.isHackPending = isHackPending
        self.cue = cue
        self.cueAt = cueAt
        self.updatedAt = updatedAt
        self.isFixStale = isFixStale
    }

    /// The readouts `snapshot` produces at its own send time, plus the latest cue while it is
    /// still recent.
    ///
    /// Evaluated at `snapshot.sentAt` (the phone's clock for that tick) rather than "now", so the
    /// content matches the flight screen for the same tick exactly. A cue older than
    /// `LiveActivityPolicy.cueDisplayDuration` is dropped; dropping it is a visible change, so
    /// the policy sends the update that clears it.
    public init(snapshot: FlightSnapshot, cue: Callout.Event? = nil, cueAt: Date? = nil) {
        let now = snapshot.sentAt
        let timing = snapshot.timing(at: now)
        let cueIsRecent = cueAt.map { now.timeIntervalSince($0) < LiveActivityPolicy.cueDisplayDuration } ?? false
        self.init(tot: snapshot.isHackPending ? nil : snapshot.tot,
                  eta: timing.eta,
                  delta: timing.delta.flatMap { $0.isFinite ? Int($0) : nil },
                  status: timing.status,
                  isHackPending: snapshot.isHackPending,
                  cue: cueIsRecent ? cue : nil,
                  cueAt: cueIsRecent ? cueAt : nil,
                  updatedAt: now,
                  isFixStale: snapshot.isStale(at: now))
    }

    /// Which side of the ToT Δ falls, for the EARLY / LATE / ON TIME word shown next to it so
    /// the status is not carried by colour alone (B-11). Nil with no Δ.
    public var deltaRelation: Callout.DriftRelation? {
        guard let delta else { return nil }
        if delta < 0 { return .early }
        if delta > 0 { return .late }
        return .onTime
    }

    /// Whether `self` and `other` would draw the same, so an update can be skipped.
    ///
    /// `updatedAt` never shows. ETA is compared to the second either way: it is already whole
    /// seconds, and a one-second wobble from GPS speed noise is not worth an update on its own
    /// (when there is a ToT the same wobble moves Δ, which does trigger one).
    public func looksTheSame(as other: FlightActivityContent) -> Bool {
        let etaClose: Bool
        switch (eta, other.eta) {
        case (nil, nil): etaClose = true
        case let (a?, b?): etaClose = abs(a.timeIntervalSince(b)) <= 1
        default: etaClose = false
        }
        return etaClose
            && tot == other.tot
            && delta == other.delta
            && status == other.status
            && isHackPending == other.isHackPending
            && cue == other.cue
            && cueAt == other.cueAt
            && isFixStale == other.isFixStale
    }
}

/// When the app sends Live Activity updates, and when the system should call one out of date.
public enum LiveActivityPolicy {
    /// With nothing visible changing, the app still re-sends this often while the flight screen
    /// is open, purely to push `staleDate` forward. Every 5 s rather than every 1 Hz tick keeps
    /// ActivityKit traffic (and battery) down without the STALE state ever tripping in the
    /// foreground.
    public static let keepAliveInterval: TimeInterval = 5

    /// How long after `updatedAt` the system marks the activity stale (`context.isStale`).
    ///
    /// Twice `TimingEngine.staleFixThreshold` (30 s). The app only updates while the flight
    /// screen is foreground (no background location), so once the phone app is backgrounded or
    /// killed the widget must stop trusting Δ on its own: the system flips it to STALE at this
    /// date with no update from the app. It is longer than the 15 s fix threshold because
    /// ActivityKit does not promise prompt delivery: updates can be coalesced or delayed, and
    /// a STALE flashing on while the app is open and fine would teach the pilot to ignore it.
    /// 30 s is six keep-alives of margin and still short next to a typical ToT run-in.
    public static let staleAfter: TimeInterval = 2 * TimingEngine.staleFixThreshold

    /// How long the latest cue stays on the Live Activity. Longer than the in-app banner (4 s):
    /// a lock-screen or wrist glance comes later than a look at the open app.
    public static let cueDisplayDuration: TimeInterval = 10

    /// The `staleDate` to send with `content`.
    public static func staleDate(for content: FlightActivityContent) -> Date {
        content.updatedAt.addingTimeInterval(staleAfter)
    }

    /// Whether to send `next`, given the last content sent (`previous`, at `lastSentAt`).
    ///
    /// Always for the first content; whenever anything visible changed (Δ, status, ToT, ETA
    /// beyond a second, hack pending, fix staleness, the cue); otherwise only once
    /// `keepAliveInterval` has passed, to keep `staleDate` ahead.
    public static func shouldUpdate(previous: FlightActivityContent?,
                                    next: FlightActivityContent,
                                    lastSentAt: Date?,
                                    now: Date) -> Bool {
        guard let previous, let lastSentAt else { return true }
        if !next.looksTheSame(as: previous) { return true }
        return now.timeIntervalSince(lastSentAt) >= keepAliveInterval
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// The Live Activity for one flight (F-02). Static for the life of the activity: the mission.
public struct FlightActivityAttributes: ActivityAttributes, Hashable, Sendable {
    public typealias ContentState = FlightActivityContent

    public var missionName: String
    public var missionType: MissionType

    public init(missionName: String, missionType: MissionType) {
        self.missionName = missionName
        self.missionType = missionType
    }
}
#endif
