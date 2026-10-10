//
//  WatchSendPolicy.swift
//  FormationFlightCore
//
//  F-02: when the phone sends what to the watch companion. Pure so the decisions are tested
//  here; the app's `WatchMirror` only carries them out.
//

import Foundation

/// The phone's two WatchConnectivity channels and when each is used.
///
/// - `sendMessage` is immediate but only works while the watch app is reachable (running and
///   in range). Every snapshot and every cue goes this way when it can, which is what makes
///   the watch feel live: it ticks locally and each message corrects it.
/// - `updateApplicationContext` is delivered whenever the system gets to it, even to a watch
///   app that is not running, and only the latest one is kept. It is how a watch app opened
///   mid-flight (or out of reach for a while) gets the current state at once. It is not meant
///   for 1 Hz traffic, so it is sent on a visible change, as a keep-alive, and always for the
///   end of the flight.
///
/// Cues never use the application context: one delivered late would tap the wrist about
/// something long past, so an unreachable watch simply misses it.
public enum WatchSendPolicy {
    /// With no visible change the context is still refreshed this often. A watch that only
    /// hears the context (not reachable) must see `sentAt` move well inside
    /// `TimingEngine.staleFixThreshold` (15 s) or it would show STALE while the phone is fine;
    /// 5 s matches the Live Activity keep-alive (`LiveActivityPolicy.keepAliveInterval`).
    public static let contextKeepAliveInterval: TimeInterval = 5

    /// Whether to send per-tick messages at all: only to a reachable watch app.
    public static func shouldSendMessage(isReachable: Bool) -> Bool {
        isReachable
    }

    /// Whether `next` should replace the application context, given the last one sent
    /// (`previous`, at phone time `lastSentAt`).
    ///
    /// Always for the first snapshot and for the ended one (so the watch leaves the flight
    /// rather than go STALE); whenever something visible changed (`changesVisibly`);
    /// otherwise once `contextKeepAliveInterval` has passed.
    public static func shouldUpdateContext(previous: FlightSnapshot?,
                                           next: FlightSnapshot,
                                           lastSentAt: Date?) -> Bool {
        guard let previous, let lastSentAt else { return true }
        if next.isEnded { return true }
        if changesVisibly(from: previous, to: next) { return true }
        return next.sentAt.timeIntervalSince(lastSentAt) >= contextKeepAliveInterval
    }

    /// Whether going from `previous` to `next` changes what the watch shows in a way the next
    /// keep-alive would be too late for: the mission, ToT, hack state, fix staleness, the end,
    /// the pilot's units or tolerances, the orbit, or the status band at each one's send time.
    ///
    /// Distance, speed and track move on every fix; on their own they ride the keep-alive.
    /// The watch extrapolates between snapshots anyway, and a reachable watch already gets
    /// every tick by message.
    public static func changesVisibly(from previous: FlightSnapshot, to next: FlightSnapshot) -> Bool {
        if previous.missionName != next.missionName
            || previous.missionType != next.missionType
            || previous.tot != next.tot
            || previous.isHackPending != next.isHackPending
            || previous.isFixStale != next.isFixStale
            || previous.isEnded != next.isEnded
            || previous.speedUnit != next.speedUnit
            || previous.distanceUnit != next.distanceUnit
            || previous.yellowTolerance != next.yellowTolerance
            || previous.redTolerance != next.redTolerance
            || previous.turnDirection != next.turnDirection {
            return true
        }
        // A first fix (or losing speed) turns Δ on or off.
        if (previous.groundSpeed == nil) != (next.groundSpeed == nil) { return true }
        return previous.timing(at: previous.sentAt).status != next.timing(at: next.sentAt).status
    }
}
