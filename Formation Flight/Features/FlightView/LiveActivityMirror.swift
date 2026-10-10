//
//  LiveActivityMirror.swift
//  Formation Flight
//
//  F-02: mirrors the open flight screen to a Live Activity (lock screen, Dynamic Island and,
//  through iOS, the Apple Watch Smart Stack). The widget extension draws it; this decides when
//  to start, update and end it.
//

import Foundation
import ActivityKit
import FormationFlightCore

// MARK: - ActivityKit seam

/// The ActivityKit calls the mirror makes, behind a protocol so its decisions (when to start,
/// what to send, when to end) are unit-tested with a fake. `ActivityKitLiveActivities` is the
/// real one.
@MainActor
protocol LiveActivityControlling: AnyObject {
    /// `ActivityAuthorizationInfo().areActivitiesEnabled`: false when the pilot turned Live
    /// Activities off for the app.
    var areActivitiesEnabled: Bool { get }
    /// Ends every Live Activity of ours still running, left over from a flight the app never
    /// got to end (crash, force quit, or a phone that died mid-flight).
    func endAll() async
    /// Starts the activity. Called only while the flight screen is foreground, as ActivityKit
    /// requires.
    func start(attributes: FlightActivityAttributes, content: FlightActivityContent, staleDate: Date) throws
    func update(_ content: FlightActivityContent, staleDate: Date) async
    /// Ends the started activity with `content` as its final state, removing it at once.
    func end(_ content: FlightActivityContent?) async
}

/// The real ActivityKit, tracking the one activity this flight started.
///
/// Holds the activity's id rather than the `Activity` itself: `Activity` is not `Sendable`, so a
/// main-actor stored one cannot be handed to its own nonisolated `update`/`end`. Looking it up
/// in `Activity.activities` each time yields a fresh, unshared reference that can be.
@MainActor
final class ActivityKitLiveActivities: LiveActivityControlling {
    private var activityID: String?

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func endAll() async {
        for leftover in Activity<FlightActivityAttributes>.activities {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
    }

    func start(attributes: FlightActivityAttributes, content: FlightActivityContent, staleDate: Date) throws {
        // Local updates only (`pushType: nil`): the app is free and has no server, and the
        // activity is meant to go STALE once the flight screen stops updating it.
        let activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: content, staleDate: staleDate),
                                            pushType: nil)
        activityID = activity.id
    }

    func update(_ content: FlightActivityContent, staleDate: Date) async {
        guard let activityID, let activity = Self.activity(withID: activityID) else { return }
        await activity.update(ActivityContent(state: content, staleDate: staleDate))
    }

    func end(_ content: FlightActivityContent?) async {
        guard let activityID, let activity = Self.activity(withID: activityID) else { return }
        self.activityID = nil
        // `.immediate`: End Flight means the pilot is done with it; an ended activity left on
        // the lock screen for hours would only show old numbers.
        await activity.end(content.map { ActivityContent(state: $0, staleDate: nil) },
                           dismissalPolicy: .immediate)
    }

    /// Nonisolated so the result is not main-actor state and can be sent to `update`/`end`.
    private nonisolated static func activity(withID id: String) -> Activity<FlightActivityAttributes>? {
        Activity<FlightActivityAttributes>.activities.first { $0.id == id }
    }
}

// MARK: - Mirror

/// Starts a Live Activity with the flight's first snapshot, updates it as the update policy
/// allows, and ends it with the flight.
///
/// Only runs while the flight screen is open: the app has no background location, so once it
/// is backgrounded the updates stop and the activity's `staleDate` (`LiveActivityPolicy`) turns
/// it STALE on its own rather than leaving Δ looking live.
///
/// ActivityKit calls are async; they run one at a time, in order, on a single chain of tasks,
/// so an update can never overtake the request that starts the activity or the end that
/// finishes it.
@MainActor
final class LiveActivityMirror: FlightMirroring {
    private enum Phase {
        /// Nothing requested yet; waiting for the first live snapshot.
        case idle
        /// Requested (the request may still be queued on the chain).
        case running
        /// Ended, disabled, or the request failed: ignore everything from here on.
        case finished
    }

    private let controller: LiveActivityControlling
    private var phase: Phase = .idle

    /// The latest snapshot, to rebuild the content when a callout arrives between ticks.
    private var lastSnapshot: FlightSnapshot?
    /// The latest cue and the phone time it was emitted (F-01).
    private var cue: Callout.Event?
    private var cueAt: Date?

    /// What was last handed to ActivityKit, and when (phone clock), for the update policy.
    private var lastSent: FlightActivityContent?
    private var lastSentAt: Date?

    /// Tail of the ActivityKit work chain.
    private var pending: Task<Void, Never>?

    private static let log = AppLogger.flight

    init(controller: LiveActivityControlling = ActivityKitLiveActivities()) {
        self.controller = controller
    }

    // MARK: FlightMirroring

    func flightDidUpdate(_ snapshot: FlightSnapshot) {
        guard phase != .finished else { return }
        lastSnapshot = snapshot
        // The final `isEnded` snapshot only supplies the end content; `flightDidEnd` follows.
        guard !snapshot.isEnded else { return }

        if phase == .idle {
            startActivity(with: snapshot)
        } else {
            sendIfNeeded(content(for: snapshot), now: snapshot.sentAt)
        }
    }

    func flightDidEmit(_ callout: Callout) {
        // Callouts follow the tick's snapshot, so its send time is the cue's time.
        guard phase == .running, let snapshot = lastSnapshot, !snapshot.isEnded else { return }
        cue = callout.event
        cueAt = snapshot.sentAt
        sendIfNeeded(content(for: snapshot), now: snapshot.sentAt)
    }

    func flightDidEnd() {
        let wasRunning = phase == .running
        phase = .finished
        guard wasRunning else { return }
        // Final content for the instant before removal: the end-of-flight snapshot, no cue.
        let final = lastSnapshot.map { FlightActivityContent(snapshot: $0) }
        enqueue { controller in
            await controller.end(final)
        }
    }

    // MARK: Test support

    /// Waits for every queued ActivityKit call to finish.
    func waitForPendingWork() async {
        await pending?.value
    }

    // MARK: Private

    private func content(for snapshot: FlightSnapshot) -> FlightActivityContent {
        FlightActivityContent(snapshot: snapshot, cue: cue, cueAt: cueAt)
    }

    private func startActivity(with snapshot: FlightSnapshot) {
        guard controller.areActivitiesEnabled else {
            phase = .finished
            return
        }
        phase = .running
        let attributes = FlightActivityAttributes(missionName: snapshot.missionName,
                                                  missionType: snapshot.missionType)
        let content = content(for: snapshot)
        lastSent = content
        lastSentAt = snapshot.sentAt
        enqueue { [weak self] controller in
            // Clear anything a previous run left behind first, so there is only ever one.
            await controller.endAll()
            do {
                try controller.start(attributes: attributes, content: content,
                                     staleDate: LiveActivityPolicy.staleDate(for: content))
            } catch {
                Self.log.error("Could not start the Live Activity: \(error.localizedDescription, privacy: .public)")
                self?.phase = .finished
            }
        }
    }

    private func sendIfNeeded(_ content: FlightActivityContent, now: Date) {
        guard LiveActivityPolicy.shouldUpdate(previous: lastSent, next: content,
                                              lastSentAt: lastSentAt, now: now) else { return }
        lastSent = content
        lastSentAt = now
        enqueue { [weak self] controller in
            // A failed start finishes the mirror; queued updates then have nothing to update.
            guard self?.phase == .running else { return }
            await controller.update(content, staleDate: LiveActivityPolicy.staleDate(for: content))
        }
    }

    /// Appends `work` to the chain. The controller is captured strongly so a flight screen
    /// closing (and releasing this mirror) cannot drop the queued end.
    private func enqueue(_ work: @escaping @MainActor (LiveActivityControlling) async -> Void) {
        let previous = pending
        let controller = controller
        pending = Task { @MainActor in
            await previous?.value
            await work(controller)
        }
    }
}
