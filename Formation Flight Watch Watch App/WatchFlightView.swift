//
//  WatchFlightView.swift
//  Formation Flight Watch Watch App
//
//  F-02: the watch screen. Ticks once a second on the watch clock with a `TimelineView` and
//  draws `WatchFlightDisplay` for that instant: idle, awaiting hack, the live flight, STALE, or
//  ended.
//

// Compiled only once the target links FormationFlightCore (see Formation_Flight_WatchApp.swift).
#if canImport(FormationFlightCore)
import SwiftUI
import FormationFlightCore

struct WatchFlightView: View {
    let model: WatchFlightModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        // Always-On: once a minute is plenty for a minutes-only face, and saves power.
        TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 60 : 1)) { context in
            WatchFlightScreen(display: WatchFlightDisplay(state: model.state, now: context.date),
                              now: context.date)
        }
    }
}

/// One frame, from plain values (so previews need no model or clock).
struct WatchFlightScreen: View {
    let display: WatchFlightDisplay
    let now: Date

    var body: some View {
        NavigationStack {
            Group {
                switch display.phase {
                case .idle:
                    IdleView()
                case .ended:
                    EndedView()
                case .awaitingHack:
                    AwaitingHackView(display: display)
                case .active, .stale:
                    ActiveFlightView(display: display, now: now)
                }
            }
            .navigationTitle(display.phase == .idle || display.phase == .ended ? "" : display.missionName)
            .containerBackground(backgroundTint.gradient, for: .navigation)
        }
    }

    /// Full-screen status colour (watchOS design language), muted when there is nothing live.
    private var backgroundTint: Color {
        if display.isStale { return Color.gray.opacity(0.35) }
        switch display.phase {
        case .active: return display.status.tint.opacity(0.45)
        case .awaitingHack: return Color.accentColor.opacity(0.4)
        default: return Color.accentColor.opacity(0.25)
        }
    }
}

// MARK: - Phases

private struct IdleView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.title)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Start a flight on your iPhone", comment: "Watch idle: no flight open on the phone")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EndedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Flight ended", comment: "Watch: the phone ended the flight")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AwaitingHackView: View {
    let display: WatchFlightDisplay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                BannerView(text: display.bannerText)
                Text("AWAITING HACK", comment: "Watch: hack mission, Hack! not pressed yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Press Hack! on iPhone", comment: "Watch: how to start the hack countdown")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let hack = display.hackTimeText {
                    ReadoutRow(label: String(localized: "Hack", comment: "Watch: hack duration label"),
                               value: hack)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActiveFlightView: View {
    let display: WatchFlightDisplay
    let now: Date
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if !isLuminanceReduced {
                    BannerView(text: display.bannerText)
                }
                countdown
                if display.isStale {
                    StaleBlock(display: display, now: now)
                } else {
                    DeltaRow(display: display, compact: isLuminanceReduced)
                }
                if !isLuminanceReduced {
                    readouts
                        .opacity(display.isStale ? 0.4 : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The ToT is an absolute time, so the countdown keeps running while STALE, dimmed with
    /// the rest so the screen does not look half-live.
    private var countdown: some View {
        Text(isLuminanceReduced ? display.countdownMinutesText : display.countdownText)
            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(isLuminanceReduced ? .identity : .numericText(countsDown: true))
            .opacity(display.isStale ? 0.5 : 1)
            .accessibilityLabel(display.countdownAccessibilityLabel)
    }

    private var readouts: some View {
        VStack(alignment: .leading, spacing: 2) {
            ReadoutRow(label: String(localized: "ETE", comment: "Watch: estimated time en route"),
                       value: display.eteText,
                       caption: display.turnCaption)
            ReadoutRow(label: String(localized: "Req GS", comment: "Watch: required ground speed"),
                       value: display.requiredSpeedText)
            ReadoutRow(label: String(localized: "GS", comment: "Watch: current ground speed"),
                       value: display.currentSpeedText)
        }
    }
}

// MARK: - Pieces

/// Δ with its symbol and EARLY / LATE / ON TIME word, tinted by status (never colour alone).
private struct DeltaRow: View {
    let display: WatchFlightDisplay
    /// Always-On: the word and symbol only, no seconds.
    let compact: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: display.statusSymbol)
            if !compact {
                Text("Δ \(display.deltaText)", comment: "Watch: delta readout, e.g. Δ +0:07")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            if let word = display.relationWord {
                Text(word)
                    .font(.caption.weight(.bold))
            }
        }
        .foregroundStyle(display.status.tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.deltaAccessibilityLabel)
    }
}

/// The STALE treatment in place of Δ: a badge, what to do, and how old the data is.
private struct StaleBlock: View {
    let display: WatchFlightDisplay
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text("STALE", comment: "Watch: data is out of date")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.headline.weight(.heavy))
            .foregroundStyle(Color(.statusWarning))
            if let instruction = display.staleInstruction {
                Text(instruction)
                    .font(.footnote)
            }
            if let age = display.staleAgeText(at: now) {
                Text(age)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The latest callout (F-01), for the banner duration.
private struct BannerView: View {
    let text: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let text {
                Label(text, systemImage: "speaker.wave.2.fill")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.opacity)
                    .accessibilityLabel(Text("Callout: \(text)", comment: "Watch VoiceOver: the latest callout"))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: text)
    }
}

private struct ReadoutRow: View {
    let label: String
    let value: String
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .font(.body.monospacedDigit().weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let caption {
                    Text(caption)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension TimingStatus {
    /// Bright status colours for the always-dark watch (the iPhone's dark-appearance values).
    var tint: Color {
        switch self {
        case .good: Color(.statusGood)
        case .bad: Color(.statusWarning)
        case .reallyBad: Color(.statusBad)
        case .unknown: .secondary
        }
    }
}

// MARK: - Previews

#if DEBUG
enum WatchPreviewData {
    /// A flight `totIn` s from ToT and 1000 s out at `groundSpeed` m/s (plus a modelled turn
    /// when `track` points away from the target, which lies due north), sent `age` s ago.
    static func state(totIn: TimeInterval = 100,
                      groundSpeed: Double = 10,
                      track: Double? = nil,
                      age: TimeInterval = 0,
                      isHackPending: Bool = false,
                      isFixStale: Bool = false,
                      cue: Callout.Event? = nil) -> WatchFlightState {
        let now = Date.now
        let sentAt = now.addingTimeInterval(-age)
        var state = WatchFlightState()
        state.receive(FlightSnapshot(
            sentAt: sentAt, missionName: "Rose Bowl Flyover",
            missionType: isHackPending ? .hackTime : .tot,
            tot: isHackPending ? nil : now.addingTimeInterval(totIn),
            hackTime: isHackPending ? 270 : nil, isHackPending: isHackPending,
            fixTime: isHackPending ? nil : sentAt.addingTimeInterval(isFixStale ? -20 : 0),
            distance: groundSpeed * 1000, groundSpeed: isHackPending ? nil : groundSpeed,
            track: track, bearing: track == nil ? nil : 0, turnDirection: nil,
            isFixStale: isFixStale, yellowTolerance: 5, redTolerance: 10,
            speedUnit: .kts, distanceUnit: .nm))
        if let cue {
            _ = state.receive(Callout(cue), emittedAt: sentAt, at: now)
        }
        return state
    }

    static func screen(_ state: WatchFlightState) -> WatchFlightScreen {
        WatchFlightScreen(display: WatchFlightDisplay(state: state, now: .now), now: .now)
    }
}

#Preview("Idle") {
    WatchPreviewData.screen(WatchFlightState())
}

#Preview("Awaiting hack") {
    WatchPreviewData.screen(WatchPreviewData.state(isHackPending: true))
}

#Preview("On time") {
    WatchPreviewData.screen(WatchPreviewData.state(totIn: 1000, groundSpeed: 100))
}

#Preview("Early, turning") {
    WatchPreviewData.screen(WatchPreviewData.state(totIn: 1300, groundSpeed: 100, track: 135,
                                                   cue: .drift(seconds: 120, relation: .early)))
}

#Preview("Late with callout") {
    WatchPreviewData.screen(WatchPreviewData.state(totIn: 993, groundSpeed: 100,
                                                   cue: .speed(increase: true, target: 196, unit: .kts)))
}

#Preview("Stale, phone silent") {
    WatchPreviewData.screen(WatchPreviewData.state(totIn: 1000, groundSpeed: 100, age: 42))
}

#Preview("Stale, GPS lost") {
    WatchPreviewData.screen(WatchPreviewData.state(totIn: 1000, groundSpeed: 100, isFixStale: true,
                                                   cue: .gpsLost))
}
#endif
#endif
