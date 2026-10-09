//
//  PhoneConnection.swift
//  Formation Flight Watch Watch App
//
//  F-02: the watch end of WatchConnectivity. Receives the phone's messages and application
//  context, decodes them with FormationFlightCore and hands them to the model on the main
//  actor. Read-only in v1: the watch never sends anything back.
//

import Foundation
import os
import WatchConnectivity
import FormationFlightCore

/// Owns the watch's `WCSession` delegate for the life of the app.
///
/// Both channels carry the same `WatchMessage`: per-tick messages while the phone's flight
/// screen is open and the watch app is reachable, and the application context, which is also
/// read once at activation so a watch app opened mid-flight shows the flight at once rather
/// than waiting for the next tick. Old or duplicate snapshots are fine to pass on: the model's
/// `WatchFlightState` keeps only the newest.
final class PhoneConnection: NSObject {
    /// Called on the main actor with each decoded message.
    private nonisolated let onMessage: @MainActor @Sendable (WatchMessage) -> Void
    private var didActivate = false

    private nonisolated static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FormationFlightWatch",
                                                category: "Connection")

    init(onMessage: @escaping @MainActor @Sendable (WatchMessage) -> Void) {
        self.onMessage = onMessage
    }

    /// Activates the session once; later calls do nothing.
    func activate() {
        guard !didActivate, WCSession.isSupported() else { return }
        didActivate = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Decodes on the delegate's queue and hops to the main actor with a `Sendable` value.
    /// Anything unreadable (another build's payload version, an empty context) is logged and
    /// dropped: the next message will do.
    private nonisolated func deliver(_ dictionary: [String: Any]) {
        guard !dictionary.isEmpty else { return }
        let message: WatchMessage
        do {
            message = try WatchMessage(transferDictionary: dictionary)
        } catch {
            Self.log.error("Ignoring a phone message: \(String(describing: error), privacy: .public)")
            return
        }
        let onMessage = onMessage
        Task { @MainActor in
            onMessage(message)
        }
    }
}

extension PhoneConnection: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        if let error {
            Self.log.error("WatchConnectivity activation failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        // The context the phone last set, possibly while this app was not running.
        deliver(session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliver(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }
}
