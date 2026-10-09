//
//  FlightLiveActivity.swift
//  FormationFlightWidgets
//
//  F-02: the flight's Live Activity on the lock screen, in the Dynamic Island, and (through
//  iOS) in the Apple Watch Smart Stack. Draws `FlightActivityContent` as sent by the app; the
//  only thing that moves on its own is the ToT countdown, a system timer text to an absolute
//  time. Everything measured (Δ, ETA) is only as fresh as the last update, so when the app
//  stops updating (backgrounded, killed) the activity goes STALE rather than look live.
//

import ActivityKit
import FormationFlightCore
import SwiftUI
import WidgetKit

struct FlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            FlightActivityContentView(model: FlightActivityModel(context: context))
        } dynamicIsland: { context in
            let model = FlightActivityModel(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(model.missionName)
                        .font(.headline)
                        .lineLimit(1)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusBadge(model: model)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            CountdownView(model: model, font: .system(.title, design: .rounded, weight: .semibold))
                            Spacer(minLength: 8)
                            DeltaView(model: model, font: .title3)
                        }
                        FooterLine(model: model)
                    }
                }
            } compactLeading: {
                StatusIcon(model: model)
            } compactTrailing: {
                CountdownView(model: model, font: .caption.weight(.semibold), compact: true)
                    .frame(maxWidth: 64)
            } minimal: {
                StatusIcon(model: model)
            }
            .keylineTint(model.tint)
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Model

/// The content as the views need it: staleness folded in, labels and tints chosen once.
struct FlightActivityModel {
    let missionName: String
    let state: FlightActivityContent
    /// The system's stale date passed (the app stopped updating) or the phone's fix is stale.
    let isStale: Bool

    // Assigns directly rather than delegating to the other init: Xcode's preview thunks wrap
    // expressions and cannot compile a wrapped `self.init`.
    init(context: ActivityViewContext<FlightActivityAttributes>) {
        missionName = context.attributes.missionName
        state = context.state
        isStale = context.isStale || context.state.isFixStale
    }

    init(missionName: String, state: FlightActivityContent, isSystemStale: Bool) {
        self.missionName = missionName
        self.state = state
        self.isStale = isSystemStale || state.isFixStale
    }

    /// Δ to trust, nil while stale: a frozen Δ would read as live.
    var delta: Int? { isStale ? nil : state.delta }
    var status: TimingStatus { isStale ? .unknown : state.status }

    var tint: Color {
        switch status {
        case .good: Color(.statusGood)
        case .bad: Color(.statusWarning)
        case .reallyBad: Color(.statusBad)
        case .unknown: .secondary
        }
    }

    /// Shape cue next to the tint (D-01).
    var symbolName: String {
        if isStale { return "exclamationmark.triangle" }
        switch status {
        case .good: return "checkmark.circle.fill"
        case .bad: return "exclamationmark.triangle.fill"
        case .reallyBad: return "xmark.octagon.fill"
        case .unknown: return "airplane"
        }
    }

    /// EARLY / LATE / ON TIME, so status never rests on colour alone (B-11).
    var relationWord: String? {
        guard delta != nil, let relation = state.deltaRelation else { return nil }
        switch relation {
        case .early: return String(localized: "EARLY", comment: "Live Activity Δ: ETA is before ToT")
        case .late: return String(localized: "LATE", comment: "Live Activity Δ: ETA is after ToT")
        case .onTime: return String(localized: "ON TIME", comment: "Live Activity Δ: ETA equals ToT")
        }
    }

    /// Signed Δ as `+0:07` / `-1:05` / `0:00`, or `--:--` when unknown or stale.
    var deltaText: String {
        guard let delta else { return "--:--" }
        // Shared with the watch companion (F-02) so both read Δ the same way.
        return FlightFormatting.compactDuration(TimeInterval(delta), signed: true)
    }

    var deltaAccessibilityLabel: String {
        guard let delta, let relation = state.deltaRelation else {
            return isStale
                ? String(localized: "Delta unavailable, stale", comment: "Live Activity VoiceOver: Δ hidden while stale")
                : String(localized: "Delta unknown", comment: "Live Activity VoiceOver: no Δ yet")
        }
        let amount = Duration.seconds(abs(delta)).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
        switch relation {
        case .early: return String(localized: "Early by \(amount)", comment: "Live Activity VoiceOver: Δ early")
        case .late: return String(localized: "Late by \(amount)", comment: "Live Activity VoiceOver: Δ late")
        case .onTime: return String(localized: "On time", comment: "Live Activity VoiceOver: Δ zero")
        }
    }

    /// The latest cue's phrase (F-01), from the package's catalog.
    var cueText: String? { state.cue?.text }

    var etaText: String? {
        guard !isStale, let eta = state.eta else { return nil }
        return eta.formatted(Self.timeStyle)
    }

    /// The countdown range, or nil for a hack pending, no ToT, or a ToT already reached by the
    /// last update (the timer text would otherwise need a backwards range).
    var countdownRange: ClosedRange<Date>? {
        guard !state.isHackPending, let tot = state.tot, tot > state.updatedAt else { return nil }
        return state.updatedAt...tot
    }

    /// What replaces the countdown when there is none.
    var countdownPlaceholder: String {
        if state.isHackPending {
            return String(localized: "AWAITING HACK", comment: "Live Activity: hack mission, Hack! not pressed yet")
        }
        if state.tot != nil {
            return String(localized: "MARK", comment: "Live Activity: ToT reached")
        }
        return "--:--"
    }

    private static let timeStyle = Date.FormatStyle(date: .omitted, time: .standard)
        .locale(Locale(identifier: "en_GB"))
}

// MARK: - Lock screen, banner and Smart Stack

struct FlightActivityContentView: View {
    @Environment(\.activityFamily) private var activityFamily
    let model: FlightActivityModel

    var body: some View {
        switch activityFamily {
        case .small:
            // The watch renders in dark appearance (white text), but an asset tint can resolve
            // to its light variant there, putting white on pale blue. Pin the dark variant of
            // FlightBackground (#0A1A2E) so the Smart Stack always matches the app at night.
            SmallFlightView(model: model)
                .activityBackgroundTint(Color(red: 0x0A / 255, green: 0x1A / 255, blue: 0x2E / 255))
        default:
            LockScreenFlightView(model: model)
                .activityBackgroundTint(Color(.flightBackground))
                .activitySystemActionForegroundColor(.primary)
        }
    }
}

/// iPhone lock screen and banner (`.medium`).
struct LockScreenFlightView: View {
    let model: FlightActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(model.missionName, systemImage: "airplane")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                StatusBadge(model: model)
            }
            HStack(alignment: .firstTextBaseline) {
                CountdownView(model: model, font: .system(size: 40, weight: .semibold, design: .rounded))
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    DeltaView(model: model, font: .title2)
                    if let eta = model.etaText {
                        Text("ETA \(eta)", comment: "Live Activity: estimated time of arrival, HH:mm:ss")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            FooterLine(model: model)
        }
        .padding()
    }
}

/// Apple Watch Smart Stack (`.small`): countdown and Δ only.
struct SmallFlightView: View {
    let model: FlightActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                StatusIcon(model: model)
                Text(model.missionName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            CountdownView(model: model, font: .system(.title3, design: .rounded, weight: .semibold))
            if model.isStale {
                StaleLabel(short: true)
            } else {
                DeltaView(model: model, font: .caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Pieces

/// ToT countdown that ticks on its own, or the hack / mark placeholder.
struct CountdownView: View {
    let model: FlightActivityModel
    let font: Font
    var compact = false

    var body: some View {
        Group {
            if let range = model.countdownRange {
                Text(timerInterval: range, countsDown: true, showsHours: true)
                    .monospacedDigit()
            } else {
                Text(model.countdownPlaceholder)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .font(font)
        .multilineTextAlignment(compact ? .trailing : .leading)
        // The ToT is absolute, so the countdown stays right while stale; dimmed with the rest so
        // the screen does not look half-live.
        .opacity(model.isStale ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Time to ToT", comment: "Live Activity VoiceOver: label for the ToT countdown"))
    }
}

/// Δ with its EARLY / LATE / ON TIME word, tinted by status.
struct DeltaView: View {
    let model: FlightActivityModel
    let font: Font

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Δ \(model.deltaText)", comment: "Live Activity: delta readout, e.g. Δ +0:07")
                .font(font.monospacedDigit().weight(.semibold))
            if let word = model.relationWord {
                Text(word)
                    .font(.caption.weight(.bold))
            }
        }
        .foregroundStyle(model.tint)
        .opacity(model.isStale ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.deltaAccessibilityLabel)
    }
}

struct StatusIcon: View {
    let model: FlightActivityModel

    var body: some View {
        Image(systemName: model.symbolName)
            .foregroundStyle(model.isStale ? Color.secondary : model.tint)
            .accessibilityLabel(model.isStale
                                ? Text("Stale", comment: "Live Activity VoiceOver: data is out of date")
                                : Text(model.relationWord ?? model.missionName))
    }
}

struct StatusBadge: View {
    let model: FlightActivityModel

    var body: some View {
        if model.isStale {
            StaleLabel(short: true)
        } else {
            StatusIcon(model: model)
                .font(.title3)
        }
    }
}

/// The STALE treatment: replaces the cue line, and says how to get live numbers back.
struct StaleLabel: View {
    var short = false

    var body: some View {
        Label {
            if short {
                Text("STALE", comment: "Live Activity: data is out of date (short)")
            } else {
                Text("STALE — open Formation Flight", comment: "Live Activity: data is out of date; open the app to resume")
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color(.statusWarning))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// STALE notice, otherwise the latest cue while it is recent.
struct FooterLine: View {
    let model: FlightActivityModel

    var body: some View {
        if model.isStale {
            StaleLabel()
        } else if let cue = model.cueText {
            Label(cue, systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .accessibilityLabel(Text("Callout: \(cue)", comment: "Live Activity VoiceOver: the latest callout"))
        }
    }
}

// MARK: - Previews

extension FlightActivityAttributes {
    fileprivate static let preview = FlightActivityAttributes(missionName: "Rose Bowl Flyover", missionType: .tot)
}

extension FlightActivityContent {
    fileprivate static let late = FlightActivityContent(
        tot: .now.addingTimeInterval(272), eta: .now.addingTimeInterval(279), delta: 7, status: .bad,
        isHackPending: false, cue: .drift(seconds: 7, relation: .late), cueAt: .now,
        updatedAt: .now, isFixStale: false)
    fileprivate static let onTime = FlightActivityContent(
        tot: .now.addingTimeInterval(95), eta: .now.addingTimeInterval(95), delta: 0, status: .good,
        isHackPending: false, updatedAt: .now, isFixStale: false)
    fileprivate static let hackPending = FlightActivityContent(
        tot: nil, eta: nil, delta: nil, status: .unknown, isHackPending: true, updatedAt: .now,
        isFixStale: false)
    /// The phone's fix went stale (B-07); a stale date passing looks the same.
    fileprivate static let stale = FlightActivityContent(
        tot: .now.addingTimeInterval(180), eta: nil, delta: nil, status: .unknown,
        isHackPending: false, updatedAt: .now, isFixStale: true)
}

#Preview("Lock screen", as: .content, using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityContent.late
    FlightActivityContent.onTime
    FlightActivityContent.hackPending
    FlightActivityContent.stale
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityContent.late
    FlightActivityContent.stale
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityContent.late
    FlightActivityContent.hackPending
    FlightActivityContent.stale
}

#Preview("Island minimal", as: .dynamicIsland(.minimal), using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityContent.onTime
    FlightActivityContent.stale
}
