//
//  FlightMirroring.swift
//  Formation Flight
//
//  The hook through which the flight screen is mirrored elsewhere: the Apple Watch companion
//  (over WatchConnectivity) and the Live Activity. Concrete mirrors arrive in later phases.
//

import Foundation
import FormationFlightCore

/// Receives the live flight from `FlightViewModel`.
///
/// The phone is the GPS source and the source of truth; a mirror only forwards. It is given
/// inputs, not rendered strings: a `FlightSnapshot` it can recompute readouts from on its own
/// clock, and each `Callout` as a structured event it can render as text or a haptic. There is
/// one delivery point, so the banner, the voice and every mirror see exactly the same cues.
@MainActor
protocol FlightMirroring: AnyObject {
    /// Called on every 1 Hz timing tick, immediately on Hack!, and once more with
    /// `isEnded == true` when the flight ends.
    func flightDidUpdate(_ snapshot: FlightSnapshot)
    /// Called with each callout as it is shown on the banner (F-01).
    func flightDidEmit(_ callout: Callout)
    /// Called once when the flight screen stops live updates (End Flight), after the final
    /// snapshot.
    func flightDidEnd()
}
