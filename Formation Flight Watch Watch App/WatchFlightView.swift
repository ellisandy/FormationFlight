//
//  WatchFlightView.swift
//  Formation Flight Watch Watch App
//
//  F-02: the watch screen. Ticks once a second on the watch clock with a `TimelineView` and
//  draws `WatchFlightDisplay` for that instant: idle, awaiting hack, the live flight, STALE, or
//  ended.
//

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
    /// False only in previews. Xcode 27's watchOS 27.0 preview agent traps (SIGTRAP in UIKit
    /// layout) on any ScrollView or List inside a NavigationStack, even a one-line one, while
    /// the same views run fine in the simulator. Previews therefore draw the content without
    /// the stack, losing only the navigation title and the full-screen tint.
    var inNavigationStack = true

    var body: some View {
        if inNavigationStack {
            NavigationStack { content }
        } else {
            content
        }
    }

    private var content: some View {
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
                .accessibilityIdentifier(WatchAccessibilityID.idleMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchAccessibilityID.idleScreen)
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
                .accessibilityIdentifier(WatchAccessibilityID.endedMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchAccessibilityID.endedScreen)
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
                    .accessibilityIdentifier(WatchAccessibilityID.awaitingHackTitle)
                Text("Press Hack! on iPhone", comment: "Watch: how to start the hack countdown")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(WatchAccessibilityID.awaitingHackMessage)
                if let hack = display.hackTimeText {
                    ReadoutRow(label: String(localized: "Hack", comment: "Watch: hack duration label"),
                               value: hack, identifier: WatchAccessibilityID.hackTime)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Standard watch margins, so the content lines up with the navigation title.
            .scenePadding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(WatchAccessibilityID.awaitingHackScreen)
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
            // Standard watch margins, so the content lines up with the navigation title.
            .scenePadding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(display.isStale ? WatchAccessibilityID.staleScreen : WatchAccessibilityID.activeScreen)
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
            .accessibilityIdentifier(WatchAccessibilityID.countdown)
    }

    private var readouts: some View {
        VStack(alignment: .leading, spacing: 2) {
            ReadoutRow(label: String(localized: "ETE", comment: "Watch: estimated time en route"),
                       value: display.eteText,
                       caption: display.turnCaption,
                       identifier: WatchAccessibilityID.ete)
            ReadoutRow(label: String(localized: "Req GS", comment: "Watch: required ground speed"),
                       value: display.requiredSpeedText,
                       identifier: WatchAccessibilityID.requiredGroundSpeed)
            ReadoutRow(label: String(localized: "GS", comment: "Watch: current ground speed"),
                       value: display.currentSpeedText,
                       identifier: WatchAccessibilityID.groundSpeed)
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
        // One element whose label carries the side in words ("Late by 7 seconds").
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.deltaAccessibilityLabel)
        .accessibilityIdentifier(WatchAccessibilityID.delta)
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
            .accessibilityIdentifier(WatchAccessibilityID.staleBadge)
            if let instruction = display.staleInstruction {
                Text(instruction)
                    .font(.footnote)
                    .accessibilityIdentifier(WatchAccessibilityID.staleInstruction)
            }
            if let age = display.staleAgeText(at: now) {
                Text(age)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(WatchAccessibilityID.staleAge)
            }
        }
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
                    .accessibilityIdentifier(WatchAccessibilityID.banner)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: text)
    }
}

private struct ReadoutRow: View {
    let label: String
    let value: String
    var caption: String? = nil
    let identifier: String

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
        // Read as "ETE, 16:40, TURN 0:45 L": the caption belongs to its value.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(caption.map { "\(value), \($0)" } ?? value)
        .accessibilityIdentifier(identifier)
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
/// Previews draw the UI-test scenarios (`WatchScenario`) at their launch instant.
enum WatchPreviewData {
    static func screen(_ scenario: WatchScenario) -> WatchFlightScreen {
        let now = Date.now
        return WatchFlightScreen(display: WatchFlightDisplay(state: scenario.initialState(launch: now), now: now),
                                 now: now, inNavigationStack: false)
    }
}

#Preview("Idle") {
    WatchPreviewData.screen(.idle)
}

#Preview("Awaiting hack") {
    WatchPreviewData.screen(.awaitingHack)
}

#Preview("On time") {
    WatchPreviewData.screen(.onTime)
}

#Preview("Early, turning") {
    WatchPreviewData.screen(.early)
}

#Preview("Late with callout") {
    WatchPreviewData.screen(.lateWithCallout)
}

#Preview("Stale, phone silent") {
    WatchPreviewData.screen(.stalePhoneSilent)
}

#Preview("Stale, GPS lost") {
    WatchPreviewData.screen(.staleGPSLost)
}

#Preview("Ended") {
    WatchPreviewData.screen(.ended)
}
#endif
