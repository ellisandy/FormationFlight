//
//  WatchFlightDisplay.swift
//  Formation Flight Watch Watch App
//
//  F-02: what the watch screen shows at one instant, derived from `WatchFlightState` and the
//  watch clock. Kept apart from the views so the strings and the STALE rules are previewed and
//  tested without rendering.
//

// Compiled only once the target links FormationFlightCore (see Formation_Flight_WatchApp.swift).
#if canImport(FormationFlightCore)
import Foundation
import FormationFlightCore

/// The readouts for one frame. Everything speed-derived is already blank while STALE (the
/// package's `FlightSnapshot.timing(at:)` drops the stale speed), so a stale frame can never
/// show live-looking Δ, ETE or speeds.
struct WatchFlightDisplay: Equatable {
    let phase: WatchFlightState.Phase
    let missionName: String
    /// Seconds to ToT on the watch clock; nil with no ToT (hack pending, or none set).
    let timeToToT: TimeInterval?
    /// Whole-second Δ, positive late; nil when unknown or stale.
    let delta: Int?
    let status: TimingStatus
    let ete: TimeInterval?
    let turnCaption: String?
    let requiredSpeedText: String
    let currentSpeedText: String
    /// Hack duration of a pending hack mission, seconds.
    let hackTime: TimeInterval?
    /// The latest cue's phrase while its banner is up.
    let bannerText: String?

    init(state: WatchFlightState, now: Date) {
        phase = state.phase(at: now)
        let snapshot = state.snapshot
        missionName = snapshot?.missionName ?? ""
        hackTime = snapshot?.hackTime
        bannerText = state.banner(at: now)?.text

        guard let snapshot, let timing = state.timing(at: now) else {
            timeToToT = nil
            delta = nil
            status = .unknown
            ete = nil
            turnCaption = nil
            requiredSpeedText = "--"
            currentSpeedText = "--"
            return
        }
        let isStale = if case .stale = phase { true } else { false }
        timeToToT = snapshot.isHackPending ? nil : timing.timeToToT
        delta = isStale ? nil : timing.delta.flatMap { $0.isFinite ? Int($0) : nil }
        status = isStale ? .unknown : timing.status
        ete = isStale ? nil : timing.ete
        turnCaption = isStale ? nil : FlightFormatting.turnCaption(duration: timing.turnDuration,
                                                                    direction: timing.turnInDirection)
        requiredSpeedText = isStale ? "--" : FlightFormatting.speed(metersPerSecond: timing.requiredGroundSpeed,
                                                                    unit: snapshot.speedUnit)
        currentSpeedText = isStale ? "--" : FlightFormatting.speed(metersPerSecond: snapshot.groundSpeed,
                                                                   unit: snapshot.speedUnit)
    }

    // MARK: Phase helpers

    var isStale: Bool {
        if case .stale = phase { return true }
        return false
    }

    var staleReason: WatchFlightState.StaleReason? {
        if case .stale(let reason) = phase { return reason }
        return nil
    }

    // MARK: Countdown

    /// `4:32`, `1:02:05`, or `MARK` once the ToT is reached; `--:--` with no ToT.
    var countdownText: String {
        guard let timeToToT else { return "--:--" }
        return timeToToT > 0 ? FlightFormatting.compactDuration(timeToToT) : String(localized: "MARK", comment: "Watch: ToT reached")
    }

    /// Always-On: whole minutes only, so nothing on the dimmed face changes every second.
    var countdownMinutesText: String {
        guard let timeToToT else { return "--" }
        guard timeToToT > 0 else { return String(localized: "MARK", comment: "Watch: ToT reached") }
        let minutes = Int((timeToToT / 60).rounded(.up))
        return timeToToT < 60
            ? String(localized: "<1 min", comment: "Watch Always-On: under a minute to ToT")
            : String(localized: "\(minutes) min", comment: "Watch Always-On: minutes to ToT, rounded up")
    }

    var countdownAccessibilityLabel: String {
        guard let timeToToT else {
            return String(localized: "No time on target", comment: "Watch VoiceOver: no ToT to count to")
        }
        guard timeToToT > 0 else { return String(localized: "Mark, at time on target", comment: "Watch VoiceOver: ToT reached") }
        return String(localized: "Time to ToT, \(Self.spoken(timeToToT))", comment: "Watch VoiceOver: countdown to ToT")
    }

    // MARK: Delta

    /// `+0:07` / `-1:05` / `0:00`, or `--:--` when unknown or stale; same form as the Live Activity.
    var deltaText: String {
        FlightFormatting.compactDuration(delta.map(TimeInterval.init), signed: true)
    }

    var deltaRelation: Callout.DriftRelation? {
        guard let delta else { return nil }
        if delta < 0 { return .early }
        if delta > 0 { return .late }
        return .onTime
    }

    /// EARLY / LATE / ON TIME, so status never rests on colour alone (B-11).
    var relationWord: String? {
        switch deltaRelation {
        case .early: String(localized: "EARLY", comment: "Watch Δ: ETA is before ToT")
        case .late: String(localized: "LATE", comment: "Watch Δ: ETA is after ToT")
        case .onTime: String(localized: "ON TIME", comment: "Watch Δ: ETA equals ToT")
        case nil: nil
        }
    }

    /// A shape cue next to the tint (D-01).
    var statusSymbol: String {
        if isStale { return "exclamationmark.triangle.fill" }
        switch status {
        case .good: return "checkmark.circle.fill"
        case .bad: return "exclamationmark.triangle.fill"
        case .reallyBad: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var deltaAccessibilityLabel: String {
        guard let delta, let relation = deltaRelation else {
            return isStale
                ? String(localized: "Delta unavailable, stale", comment: "Watch VoiceOver: Δ hidden while stale")
                : String(localized: "Delta unknown", comment: "Watch VoiceOver: no Δ yet")
        }
        let amount = Self.spoken(TimeInterval(abs(delta)))
        switch relation {
        case .early: return String(localized: "Early by \(amount)", comment: "Watch VoiceOver: Δ early")
        case .late: return String(localized: "Late by \(amount)", comment: "Watch VoiceOver: Δ late")
        case .onTime: return String(localized: "On time", comment: "Watch VoiceOver: Δ zero")
        }
    }

    // MARK: ETE

    var eteText: String { FlightFormatting.compactDuration(ete) }

    // MARK: STALE

    /// What to do about it.
    var staleInstruction: String? {
        switch staleReason {
        case .phoneSilent: String(localized: "Open Formation Flight on iPhone", comment: "Watch STALE: the phone stopped sending")
        case .fixLost: String(localized: "Waiting for GPS on iPhone", comment: "Watch STALE: the phone's GPS fix is stale")
        case nil: nil
        }
    }

    /// When the stale data was last fresh, for "Updated 0:42 ago".
    var staleSince: Date? {
        switch staleReason {
        case .phoneSilent(let since): since
        case .fixLost(let since): since
        case nil: nil
        }
    }

    func staleAgeText(at now: Date) -> String? {
        guard let staleSince else { return nil }
        let age = FlightFormatting.compactDuration(max(0, now.timeIntervalSince(staleSince)))
        return String(localized: "Updated \(age) ago", comment: "Watch STALE: time since the data was last fresh, m:ss")
    }

    // MARK: Hack

    var hackTimeText: String? {
        hackTime.map { FlightFormatting.compactDuration($0) }
    }

    // MARK: Private

    private static func spoken(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(seconds)).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }
}
#endif
