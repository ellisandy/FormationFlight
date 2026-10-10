//
//  WatchScenario.swift
//  Formation Flight Watch Watch App
//
//  F-02: fixed flights for previews and UI tests, which have no iPhone. Launched with
//  `-uiTestScenario <name>`, the app skips WatchConnectivity and plays the scenario into the
//  model instead, acting as a phone would: a fresh snapshot every second, built relative to
//  launch time so countdowns are live. DEBUG builds only; release builds ignore the argument.
//

#if DEBUG
import Foundation
import FormationFlightCore

enum WatchScenario: String, CaseIterable {
    case idle
    case awaitingHack
    case onTime
    /// Early by several minutes, with a modelled turn (TURN caption) and a drift cue.
    case early
    /// Late, with a speed callout re-sent every few seconds so its banner stays up.
    case lateWithCallout
    /// The phone stopped sending 42 s ago.
    case stalePhoneSilent
    /// The phone is sending, but its fix is stale (GPS lost).
    case staleGPSLost
    /// The phone has just ended the flight.
    case ended
    /// Live transition: on time, then a callout arrives `calloutDelay` after launch.
    case calloutAfterLaunch
    /// Live transition: the last snapshot was sent 8 s before launch and no more come, so the
    /// watch goes STALE about 7 s after launch (production's 15 s threshold, unchanged).
    case goesStale

    /// The launch argument that selects a scenario: `-uiTestScenario <name>`.
    static let launchArgument = "-uiTestScenario"
    static let calloutDelay: TimeInterval = 4

    init?(arguments: [String]) {
        guard let index = arguments.firstIndex(of: Self.launchArgument),
              arguments.indices.contains(index + 1)
        else { return nil }
        self.init(rawValue: arguments[index + 1])
    }

    // MARK: Flight

    /// What the pretend phone is flying: ETE at launch at `groundSpeed`, ToT `totIn` after
    /// launch, the target due north. Closing at `groundSpeed`, so Δ holds steady as it ticks.
    private struct Flight {
        var ete: TimeInterval = 1000
        var totIn: TimeInterval = 1000
        var groundSpeed: Double = 100
        var track: Double?
        var isHackPending = false
        var isFixStale = false
        var isEnded = false
    }

    private var flight: Flight? {
        switch self {
        case .idle: nil
        case .awaitingHack: Flight(isHackPending: true)
        case .onTime, .calloutAfterLaunch, .goesStale, .stalePhoneSilent: Flight()
        case .early: Flight(totIn: 1300, track: 135)
        case .lateWithCallout: Flight(totIn: 993)
        case .staleGPSLost: Flight(isFixStale: true)
        case .ended: Flight(isEnded: true)
        }
    }

    /// How long before launch the first snapshot was sent.
    private var initialAge: TimeInterval {
        switch self {
        case .stalePhoneSilent: 42
        case .goesStale: 8
        default: 0
        }
    }

    /// Whether the pretend phone keeps sending a snapshot every second.
    private var keepsSending: Bool {
        switch self {
        case .idle, .stalePhoneSilent, .ended, .goesStale: false
        default: true
        }
    }

    /// The cue already on screen at launch, if any.
    private var initialCue: Callout.Event? {
        switch self {
        case .early: .drift(seconds: 120, relation: .early)
        case .lateWithCallout: Self.lateCue
        case .staleGPSLost: .gpsLost
        default: nil
        }
    }

    static let lateCue = Callout.Event.speed(increase: true, target: 196, unit: .kts)
    static let calloutAfterLaunchCue = Callout.Event.rollOut

    private func snapshot(_ flight: Flight, launch: Date, sentAt: Date) -> FlightSnapshot {
        let elapsed = max(0, sentAt.timeIntervalSince(launch))
        return FlightSnapshot(
            sentAt: sentAt, missionName: "Rose Bowl Flyover",
            missionType: flight.isHackPending ? .hackTime : .tot,
            tot: flight.isHackPending ? nil : launch.addingTimeInterval(flight.totIn),
            hackTime: flight.isHackPending ? 270 : nil, isHackPending: flight.isHackPending,
            fixTime: flight.isHackPending ? nil
                : (flight.isFixStale ? launch.addingTimeInterval(-20) : sentAt),
            distance: flight.groundSpeed * max(0, flight.ete - elapsed),
            groundSpeed: flight.isHackPending ? nil : flight.groundSpeed,
            track: flight.track, bearing: flight.track == nil ? nil : 0, turnDirection: nil,
            isFixStale: flight.isFixStale, yellowTolerance: 5, redTolerance: 10,
            speedUnit: .kts, distanceUnit: .nm, isEnded: flight.isEnded)
    }

    // MARK: Playback

    /// The state at launch, as if the phone's latest messages had just arrived.
    func initialState(launch: Date) -> WatchFlightState {
        var state = WatchFlightState()
        guard let flight else { return state }
        let sentAt = launch.addingTimeInterval(-initialAge)
        state.receive(snapshot(flight, launch: launch, sentAt: sentAt))
        if let initialCue {
            _ = state.receive(Callout(initialCue), emittedAt: sentAt, at: launch)
        }
        return state
    }

    /// Acts as the phone after launch: a snapshot every second (scenarios where the phone is
    /// talking), plus the scenario's timed cues. Runs until cancelled (the view's `.task`).
    @MainActor
    func play(on model: WatchFlightModel, launch: Date) async {
        guard let flight, keepsSending else { return }
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            tick += 1
            let now = Date.now
            model.receive(.snapshot(snapshot(flight, launch: launch, sentAt: now)))
            switch self {
            case .lateWithCallout where tick % 3 == 0:
                model.receive(.callout(Callout(Self.lateCue), emittedAt: now))
            case .calloutAfterLaunch where tick == Int(Self.calloutDelay):
                model.receive(.callout(Callout(Self.calloutAfterLaunchCue), emittedAt: now))
            default:
                break
            }
        }
    }
}
#endif
