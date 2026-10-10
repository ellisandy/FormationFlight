//
//  CalloutSettings.swift
//  FormationFlightCore
//
//  F-01: which in-flight callouts the pilot wants, and whether they are spoken.
//

import Foundation

/// The pilot's callout preferences.
///
/// Every event type shows a banner on the flight screen when enabled; `voiceEnabled` is a
/// master switch that additionally speaks them. Decoding is lenient so that a key added or
/// removed by another build falls back to its default instead of discarding the whole set.
public struct CalloutSettings: Codable, Equatable, Sendable {
    /// Speaks callouts aloud. Banners are shown either way.
    public var voiceEnabled: Bool
    /// 5 min, 1 min, 30 s, 10 s, then 5 – 1 and "Mark" at ToT.
    public var countdownEnabled: Bool
    /// "Turn left/right now" and "Roll out now" at the modelled turn-in point.
    public var turnInEnabled: Bool
    /// Early/late announcements when Δ moves between tolerance bands.
    public var driftEnabled: Bool
    /// Speed advisories and GPS lost/restored.
    public var speedAndGPSEnabled: Bool
    /// Gap between required and current ground speed that triggers a speed advisory, knots.
    /// Stored in knots so it keeps its meaning when the pilot changes the display unit.
    public var speedThresholdKnots: Double

    /// Values the speed threshold may take, knots.
    public static let speedThresholdRangeKnots: ClosedRange<Double> = 5...30
    public static let defaultSpeedThresholdKnots: Double = 10

    /// Everything on, voice included (product decision for F-01).
    public static let defaults = CalloutSettings(
        voiceEnabled: true,
        countdownEnabled: true,
        turnInEnabled: true,
        driftEnabled: true,
        speedAndGPSEnabled: true,
        speedThresholdKnots: defaultSpeedThresholdKnots
    )

    public init(voiceEnabled: Bool,
                countdownEnabled: Bool,
                turnInEnabled: Bool,
                driftEnabled: Bool,
                speedAndGPSEnabled: Bool,
                speedThresholdKnots: Double) {
        self.voiceEnabled = voiceEnabled
        self.countdownEnabled = countdownEnabled
        self.turnInEnabled = turnInEnabled
        self.driftEnabled = driftEnabled
        self.speedAndGPSEnabled = speedAndGPSEnabled
        self.speedThresholdKnots = speedThresholdKnots
    }

    /// Returns a copy with the speed threshold clamped to `speedThresholdRangeKnots`.
    public func validated() -> CalloutSettings {
        var copy = self
        let range = Self.speedThresholdRangeKnots
        copy.speedThresholdKnots = speedThresholdKnots.isFinite
            ? min(max(speedThresholdKnots, range.lowerBound), range.upperBound)
            : Self.defaultSpeedThresholdKnots
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case voiceEnabled, countdownEnabled, turnInEnabled, driftEnabled, speedAndGPSEnabled, speedThresholdKnots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaults
        voiceEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .voiceEnabled)) ?? defaults.voiceEnabled
        countdownEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .countdownEnabled)) ?? defaults.countdownEnabled
        turnInEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .turnInEnabled)) ?? defaults.turnInEnabled
        driftEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .driftEnabled)) ?? defaults.driftEnabled
        speedAndGPSEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .speedAndGPSEnabled)) ?? defaults.speedAndGPSEnabled
        speedThresholdKnots = (try? container.decodeIfPresent(Double.self, forKey: .speedThresholdKnots)) ?? defaults.speedThresholdKnots
    }
}
