//
//  WatchMirror.swift
//  Formation Flight
//
//  F-02: mirrors the open flight screen to the Apple Watch companion app over
//  WatchConnectivity. The watch is a read-only mirror plus haptic cues; the phone stays the GPS
//  source and the source of truth. What to send when is `WatchSendPolicy` (FormationFlightCore);
//  this carries it out.
//

import Foundation
import WatchConnectivity
import FormationFlightCore

// MARK: - WatchConnectivity seam

/// Whether the session can carry anything to the watch app yet.
enum WatchSessionAvailability: Equatable {
    /// Activation has not completed: hold the latest state until it does.
    case pending
    /// Activated, with a paired watch that has the companion installed.
    case available
    /// Not supported (iPad), no paired watch, or the companion is not installed: send nothing.
    case unavailable
}

/// The WatchConnectivity calls the mirror makes, behind a protocol so its decisions are
/// unit-tested with a fake. `PhoneWatchSession` is the real one. Takes `WatchMessage`s rather
/// than dictionaries so the fake records values; encoding happens in the real session.
@MainActor
protocol WatchSessioning: AnyObject {
    var availability: WatchSessionAvailability { get }
    /// The watch app is running and in range, so `sendMessage` will be delivered now.
    var isReachable: Bool { get }
    /// Immediate delivery to a reachable watch app. Failures are logged, not reported: the next
    /// tick's message supersedes a lost one.
    func sendMessage(_ message: WatchMessage)
    /// Replaces the application context, delivered to the watch app even if it is not running.
    func updateApplicationContext(_ message: WatchMessage) throws
    /// Called on the main actor whenever `availability` or `isReachable` may have changed.
    /// One handler at a time (there is only ever one flight screen); setting it replaces the
    /// previous one.
    var stateDidChange: (@MainActor () -> Void)? { get set }
}

/// The real `WCSession.default`, activated once for the life of the app.
///
/// Activation is asynchronous and should happen early, so `Formation_FlightApp` calls
/// `activate()` at launch and pairing state is known by the time a flight starts; the mirror
/// calls it too, which is a no-op after the first time. No entitlement or capability is needed.
@MainActor
final class PhoneWatchSession: NSObject, WatchSessioning {
    static let shared = PhoneWatchSession()

    private(set) var availability: WatchSessionAvailability = .pending
    private(set) var isReachable = false
    var stateDidChange: (@MainActor () -> Void)?

    private var didActivate = false

    /// Shared with the nonisolated delegate callbacks and send-error handlers; `Logger` is
    /// `Sendable`.
    private nonisolated static let log = AppLogger.flight

    func activate() {
        guard !didActivate else { return }
        didActivate = true
        guard WCSession.isSupported() else {
            availability = .unavailable
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendMessage(_ message: WatchMessage) {
        let dictionary: [String: Any]
        do {
            dictionary = try message.transferDictionary()
        } catch {
            Self.log.error("Could not encode a watch message: \(error.localizedDescription, privacy: .public)")
            return
        }
        WCSession.default.sendMessage(dictionary, replyHandler: nil) { error in
            Self.log.debug("Watch message not delivered: \(error.localizedDescription, privacy: .public)")
        }
    }

    func updateApplicationContext(_ message: WatchMessage) throws {
        try WCSession.default.updateApplicationContext(message.transferDictionary())
    }

    private func apply(_ status: Status) {
        availability = status.availability
        isReachable = status.isReachable
        stateDidChange?()
    }

    /// The session's state, read on the delegate's queue and carried to the main actor as
    /// plain values (`WCSession` itself is not `Sendable`).
    private struct Status: Sendable {
        var availability: WatchSessionAvailability
        var isReachable: Bool

        init(_ session: WCSession) {
            if session.activationState != .activated {
                availability = .pending
            } else if session.isPaired && session.isWatchAppInstalled {
                availability = .available
            } else {
                availability = .unavailable
            }
            isReachable = session.activationState == .activated && session.isReachable
        }
    }

    private nonisolated func report(_ session: WCSession) {
        let status = Status(session)
        Task { @MainActor in
            self.apply(status)
        }
    }
}

extension PhoneWatchSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        if let error {
            Self.log.error("WatchConnectivity activation failed: \(error.localizedDescription, privacy: .public)")
        }
        report(session)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        report(session)
    }

    /// The pilot switched to another watch: activate again so the new one gets the flight.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        report(session)
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        report(session)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        report(session)
    }
}

// MARK: - Mirror

/// Sends the flight to the watch companion: every snapshot by message while the watch app is
/// reachable, the application context per `WatchSendPolicy` so a watch app opened mid-flight
/// catches up, cues by message only (a late one would tap the wrist about something past),
/// and the ended snapshot as the context so the watch leaves the flight instead of going STALE.
///
/// Until the session finishes activating the latest snapshot is held and sent as soon as it
/// does. Send errors are logged and otherwise ignored: the next tick or keep-alive corrects
/// them, and the watch's STALE state covers a link that stays down.
///
/// Only runs while the flight screen is open (no background location), so once the phone app
/// is backgrounded the watch stops hearing from it and shows STALE on its own.
@MainActor
final class WatchMirror: FlightMirroring {
    private let session: WatchSessioning
    /// `flightDidEnd` was called: ignore any later updates.
    private var isFinished = false

    /// The latest snapshot, for the time stamp of a callout that follows it.
    private var lastSnapshot: FlightSnapshot?
    /// Held while the session is still activating; only the newest matters.
    private var pending: FlightSnapshot?
    /// The last application context sent, and its phone time, for the policy.
    private var lastContext: FlightSnapshot?
    private var lastContextAt: Date?

    private static let log = AppLogger.flight

    init(session: WatchSessioning? = nil) {
        if let session {
            self.session = session
        } else {
            let shared = PhoneWatchSession.shared
            shared.activate()
            self.session = shared
        }
        self.session.stateDidChange = { [weak self] in
            self?.sessionStateDidChange()
        }
    }

    // MARK: FlightMirroring

    func flightDidUpdate(_ snapshot: FlightSnapshot) {
        guard !isFinished else { return }
        lastSnapshot = snapshot
        switch session.availability {
        case .pending:
            pending = snapshot
        case .available:
            deliver(snapshot)
        case .unavailable:
            break
        }
    }

    func flightDidEmit(_ callout: Callout) {
        // Callouts follow their tick's snapshot, so its send time is the cue's time.
        guard !isFinished, session.availability == .available,
              WatchSendPolicy.shouldSendMessage(isReachable: session.isReachable),
              let snapshot = lastSnapshot, !snapshot.isEnded
        else { return }
        session.sendMessage(.callout(callout, emittedAt: snapshot.sentAt))
    }

    func flightDidEnd() {
        // The ended snapshot came just before; it was sent (or is pending) as the context.
        isFinished = true
    }

    // MARK: Private

    private func deliver(_ snapshot: FlightSnapshot) {
        if WatchSendPolicy.shouldSendMessage(isReachable: session.isReachable) {
            session.sendMessage(.snapshot(snapshot))
        }
        guard WatchSendPolicy.shouldUpdateContext(previous: lastContext, next: snapshot,
                                                  lastSentAt: lastContextAt) else { return }
        do {
            try session.updateApplicationContext(.snapshot(snapshot))
            lastContext = snapshot
            lastContextAt = snapshot.sentAt
        } catch {
            // Left as not sent, so the next tick tries again.
            Self.log.error("Could not update the watch context: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Activation finished (or pairing / reachability changed): send what was held, which may
    /// be the ended snapshot of a flight that has already closed.
    private func sessionStateDidChange() {
        guard let held = pending, session.availability != .pending else { return }
        pending = nil
        if session.availability == .available {
            deliver(held)
        }
    }
}
