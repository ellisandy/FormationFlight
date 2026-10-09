//
//  Callout.swift
//  FormationFlightCore
//
//  F-01: one in-flight cue, described structurally so every output (banner, voice, watch
//  haptic, Live Activity) renders it from the same value.
//

import Foundation

/// One banner / spoken / haptic callout.
///
/// The cue is fully described by `event`, which carries no text. `text` and `kind` are derived
/// from it, so the watch can be sent the event alone (inputs, not strings) and render exactly
/// the phrase the phone shows, in the watch's own language, and pick the matching haptic.
public struct Callout: Equatable, Sendable, Codable {
    /// Event type, in priority order: when several are due on the same tick the first wins
    /// and the others are re-evaluated on later ticks (or dropped if no longer true).
    public enum Kind: String, Codable, Sendable {
        case countdown
        case turnIn
        case gps
        case drift
        case speed
    }

    /// Which side of the ToT a drift callout reports.
    public enum DriftRelation: String, Codable, Hashable, Sendable {
        case early
        case late
        case onTime
    }

    /// Everything needed to render the cue, without localized text.
    ///
    /// Codable because it travels to the watch; the synthesized encoding is part of the
    /// payload contract (`CorePayload.version`), so renaming a case or an
    /// associated-value label is a breaking change.
    public enum Event: Hashable, Sendable, Codable {
        /// A countdown mark: whole seconds left to ToT. 0 is "Mark".
        case countdown(secondsToToT: Int)
        /// Start the turn onto the target now, this way.
        case turnIn(TurnToTarget.Direction)
        /// Stop turning: pointed at the target.
        case rollOut
        /// Δ has settled in a new tolerance band. `seconds` is the whole-second magnitude.
        case drift(seconds: Int, relation: DriftRelation)
        /// Fly this ground speed, already converted to and rounded in `unit`.
        case speed(increase: Bool, target: Int, unit: SpeedUnit)
        case gpsLost
        case gpsRestored
    }

    public let event: Event

    public init(_ event: Event) {
        self.event = event
    }

    public var kind: Kind { event.kind }
    /// Short radio-style phrase, used for both the banner and speech.
    public var text: String { event.text }
    public var haptic: CueHaptic { event.haptic }
}

extension Callout.Event {
    public var kind: Callout.Kind {
        switch self {
        case .countdown: .countdown
        case .turnIn, .rollOut: .turnIn
        case .drift: .drift
        case .speed: .speed
        case .gpsLost, .gpsRestored: .gps
        }
    }

    /// The localized phrase for the banner and voice, from the package's string catalog.
    public var text: String {
        switch self {
        case .countdown(let seconds):
            return Self.countdownText(seconds)
        case .turnIn(.left):
            return String(localized: "Turn left now.", bundle: .module, comment: "Callout: start the turn onto the target, to the left")
        case .turnIn(.right):
            return String(localized: "Turn right now.", bundle: .module, comment: "Callout: start the turn onto the target, to the right")
        case .rollOut:
            return String(localized: "Roll out now.", bundle: .module, comment: "Callout: stop turning, now pointed at the target")
        case .drift(let seconds, let relation):
            return Self.driftText(seconds: seconds, relation: relation)
        case .speed(let increase, let target, _):
            return increase
                ? String(localized: "Increase, \(target).", bundle: .module, comment: "Callout: speed up to this ground speed, in the pilot's unit")
                : String(localized: "Reduce, \(target).", bundle: .module, comment: "Callout: slow down to this ground speed, in the pilot's unit")
        case .gpsLost:
            return String(localized: "GPS lost.", bundle: .module, comment: "Callout: the GPS fix has gone stale")
        case .gpsRestored:
            return String(localized: "GPS restored.", bundle: .module, comment: "Callout: GPS fixes are arriving again")
        }
    }

    /// The wrist tap for this cue (watch companion). The haptic is just another rendering of
    /// the same event, so the watch never runs a cue system of its own.
    ///
    /// Mapping, chosen so a pilot can tell the cue without looking:
    /// - Countdown: `.notification` for the long marks (10 s and up), `.click` for the 5 … 1
    ///   ticks, `.success` on "Mark".
    /// - Turn left/right now: `.start`; roll out now: `.stop`.
    /// - Drift: early → `.directionDown` (slow down), late → `.directionUp` (speed up),
    ///   on time → `.success`.
    /// - Speed: increase → `.directionUp`, reduce → `.directionDown`, matching drift.
    /// - GPS lost → `.failure`; restored → `.success`.
    public var haptic: CueHaptic {
        switch self {
        case .countdown(let seconds):
            if seconds <= 0 { return .success }
            return seconds >= 10 ? .notification : .click
        case .turnIn: return .start
        case .rollOut: return .stop
        case .drift(_, let relation):
            switch relation {
            case .early: return .directionDown
            case .late: return .directionUp
            case .onTime: return .success
            }
        case .speed(let increase, _, _): return increase ? .directionUp : .directionDown
        case .gpsLost: return .failure
        case .gpsRestored: return .success
        }
    }

    static func countdownText(_ mark: Int) -> String {
        switch mark {
        case 300: String(localized: "Five minutes.", bundle: .module, comment: "Callout: five minutes to ToT")
        case 60: String(localized: "One minute.", bundle: .module, comment: "Callout: one minute to ToT")
        case 30: String(localized: "Thirty seconds.", bundle: .module, comment: "Callout: thirty seconds to ToT")
        case 10: String(localized: "Ten.", bundle: .module, comment: "Callout: ten seconds to ToT")
        case 0: String(localized: "Mark.", bundle: .module, comment: "Callout: now at ToT")
        default: "\(mark)."
        }
    }

    /// "On time." inside the yellow tolerance (or with nothing to report), otherwise
    /// "Early, 12." / "Late, 1 minute, 5 seconds."
    static func driftText(seconds: Int, relation: Callout.DriftRelation) -> String {
        if relation == .onTime || seconds == 0 {
            return String(localized: "On time.", bundle: .module, comment: "Callout: Δ is within the yellow tolerance")
        }
        let amount: String
        if seconds < 60 {
            amount = "\(seconds)"
        } else {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .full
            amount = formatter.string(from: TimeInterval(seconds)) ?? "\(seconds)"
        }
        return relation == .early
            ? String(localized: "Early, \(amount).", bundle: .module, comment: "Callout: early by this many seconds, or minutes and seconds")
            : String(localized: "Late, \(amount).", bundle: .module, comment: "Callout: late by this many seconds, or minutes and seconds")
    }
}

/// A semantic wrist tap, one per `WKHapticType` the watch companion uses. Pure so the mapping
/// from cue to haptic lives (and is tested) here; the watch maps each case to the
/// `WKHapticType` of the same name.
public enum CueHaptic: String, Codable, Sendable, CaseIterable {
    case notification
    case directionUp
    case directionDown
    case success
    case failure
    case retry
    case start
    case stop
    case click
}
