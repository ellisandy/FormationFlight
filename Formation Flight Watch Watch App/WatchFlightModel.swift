//
//  WatchFlightModel.swift
//  Formation Flight Watch Watch App
//
//  F-02: the watch app's observable state. A thin shell over `WatchFlightState`
//  (FormationFlightCore), which holds the rules; this feeds it messages and the watch clock and
//  plays the haptics it asks for.
//

// Compiled only once the target links FormationFlightCore (see Formation_Flight_WatchApp.swift).
#if canImport(FormationFlightCore)
import Foundation
import Observation
import WatchKit
import FormationFlightCore

/// The flight as the watch knows it.
///
/// The model only stores inputs. Ticking is the view's job: a `TimelineView` redraws once a
/// second and asks `state` for the phase, readouts and banner at that instant on the watch
/// clock (`snapshot.timing(at:)`), so the numbers move smoothly between phone messages and
/// turn STALE on time even if the phone goes silent.
///
/// Haptics: a received cue plays its `CueHaptic` at once (F-01 cues, one delivery point on the
/// phone). They only play while this app is active or frontmost (including Always-On with the
/// wrist down). Once watchOS returns to the clock (Settings > General > Return to Clock) the
/// app is suspended and cues are missed; the Live Activity in the Smart Stack still shows the
/// flight. That is deliberate: keeping the app alive would need a workout or extended-runtime
/// session, which this app has no legitimate use for (App Review risk), so none is started.
@Observable
final class WatchFlightModel {
    private(set) var state: WatchFlightState

    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let playHaptic: @MainActor (CueHaptic) -> Void

    init(state: WatchFlightState = WatchFlightState(),
         clock: @escaping () -> Date = Date.init,
         playHaptic: @escaping @MainActor (CueHaptic) -> Void = WatchFlightModel.playOnDevice) {
        self.state = state
        self.clock = clock
        self.playHaptic = playHaptic
    }

    /// Takes a message from the phone; plays the cue's haptic when the rules allow it
    /// (fresh, not a duplicate, phone still talking: `WatchFlightState.receive`).
    func receive(_ message: WatchMessage) {
        if let haptic = state.receive(message, at: clock()) {
            playHaptic(haptic)
        }
    }

    static func playOnDevice(_ haptic: CueHaptic) {
        WKInterfaceDevice.current().play(haptic.hapticType)
    }
}

extension CueHaptic {
    /// The `WKHapticType` of the same name; the cue-to-haptic choice is made (and tested) in
    /// FormationFlightCore (`Callout.Event.haptic`).
    var hapticType: WKHapticType {
        switch self {
        case .notification: .notification
        case .directionUp: .directionUp
        case .directionDown: .directionDown
        case .success: .success
        case .failure: .failure
        case .retry: .retry
        case .start: .start
        case .stop: .stop
        case .click: .click
        }
    }
}
#endif
