//
//  SafetyDisclaimer.swift
//  Formation Flight
//
//  Aviation safety disclaimer copy and the one-time acknowledgement store (R-07).
//

import Foundation

/// The safety disclaimer shown once at first launch and available again from
/// Settings. The app is a supplemental timing aid, so App Review Guideline 1.4
/// (physical harm) makes a clear "situational awareness only" statement
/// advisable; the copy lives here so the sheet, the Settings footer, and the
/// tests all read the same strings.
enum SafetyDisclaimer {
    /// Sheet title.
    static let title = String(
        localized: "Before You Fly",
        comment: "Title of the aviation safety disclaimer shown on first launch"
    )

    /// Body paragraphs, in display order.
    static let paragraphs: [String] = [
        String(
            localized: "Formation Flight is a supplemental timing aid. It helps you track time on target, distance, bearing, and required groundspeed using your device's GPS.",
            comment: "Safety disclaimer, paragraph 1: what the app does"
        ),
        String(
            localized: "It is not a certified navigation or flight-management system and must not be used as your primary means of navigation, terrain avoidance, or traffic separation. GPS data can be delayed, degraded, or unavailable.",
            comment: "Safety disclaimer, paragraph 2: what the app is not"
        ),
        String(
            localized: "Always fly the aircraft first, follow your unit's procedures and applicable regulations, and cross-check against primary instruments.",
            comment: "Safety disclaimer, paragraph 3: pilot responsibilities"
        )
    ]

    /// Title of the acknowledgement button on the first-launch sheet.
    static let acknowledgeButtonTitle = String(
        localized: "I Understand",
        comment: "Button that acknowledges the safety disclaimer"
    )

    /// One-line reminder shown persistently in Settings.
    static let settingsFooter = String(
        localized: "Formation Flight is a supplemental timing aid for situational awareness only. It is not a substitute for primary navigation.",
        comment: "Persistent one-line safety disclaimer shown in Settings"
    )
}

/// Persists whether the pilot has acknowledged the safety disclaimer.
///
/// Backed by `UserDefaults` so a test can inject an isolated suite, and so UI
/// tests can pre-acknowledge (or force) the disclaimer with the launch
/// arguments `-hasAcknowledgedSafetyDisclaimer YES|NO`, which `UserDefaults`
/// honours without any app code.
struct SafetyDisclaimerStore {
    static let acknowledgedKey = "hasAcknowledgedSafetyDisclaimer"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `true` once the pilot has tapped "I Understand"; `false` for a fresh install.
    var hasAcknowledged: Bool {
        defaults.bool(forKey: Self.acknowledgedKey)
    }

    /// Records the acknowledgement so the sheet is not shown again.
    func acknowledge() {
        defaults.set(true, forKey: Self.acknowledgedKey)
    }

    /// Forgets the acknowledgement so the sheet shows on the next launch
    /// (for tests and debugging).
    func reset() {
        defaults.removeObject(forKey: Self.acknowledgedKey)
    }
}
