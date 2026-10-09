import Foundation
import Testing
@testable import FormationFlightCore

/// Every event with its phrase, kind and haptic. File scope so `@Test(arguments:)` can use it.
private let eventCases: [(event: Callout.Event, text: String, kind: Callout.Kind, haptic: CueHaptic)] = [
    (.countdown(secondsToToT: 300), "Five minutes.", .countdown, .notification),
    (.countdown(secondsToToT: 60), "One minute.", .countdown, .notification),
    (.countdown(secondsToToT: 30), "Thirty seconds.", .countdown, .notification),
    (.countdown(secondsToToT: 10), "Ten.", .countdown, .notification),
    (.countdown(secondsToToT: 5), "5.", .countdown, .click),
    (.countdown(secondsToToT: 1), "1.", .countdown, .click),
    (.countdown(secondsToToT: 0), "Mark.", .countdown, .success),
    (.turnIn(.left), "Turn left now.", .turnIn, .start),
    (.turnIn(.right), "Turn right now.", .turnIn, .start),
    (.rollOut, "Roll out now.", .turnIn, .stop),
    (.drift(seconds: 12, relation: .early), "Early, 12.", .drift, .directionDown),
    (.drift(seconds: 72, relation: .late), "Late, 1 minute, 12 seconds.", .drift, .directionUp),
    (.drift(seconds: 4, relation: .onTime), "On time.", .drift, .success),
    (.speed(increase: true, target: 140, unit: .kts), "Increase, 140.", .speed, .directionUp),
    (.speed(increase: false, target: 92, unit: .mph), "Reduce, 92.", .speed, .directionDown),
    (.gpsLost, "GPS lost.", .gps, .failure),
    (.gpsRestored, "GPS restored.", .gps, .success),
]

/// Structured callouts (F-01, watch companion): text, kind and haptic all derive from the event.
@Suite("Callout")
struct CalloutTests {
    @Test("Each event renders its phrase, kind and haptic", arguments: eventCases)
    func eventRendering(event: Callout.Event, text: String, kind: Callout.Kind, haptic: CueHaptic) {
        let callout = Callout(event)
        #expect(callout.text == text)
        #expect(callout.kind == kind)
        #expect(callout.haptic == haptic)
        #expect(event.text == text)
    }

    @Test("Events round-trip through JSON", arguments: eventCases.map(\.event))
    func eventCodable(event: Callout.Event) throws {
        let data = try JSONEncoder().encode(Callout(event))
        #expect(try JSONDecoder().decode(Callout.self, from: data) == Callout(event))
    }

    @Test("A zero-second early/late drift reads as on time")
    func zeroDriftIsOnTime() {
        #expect(Callout.Event.drift(seconds: 0, relation: .late).text == "On time.")
    }

    @Test("The engine's drift events carry the magnitude and side")
    func driftEvent() {
        #expect(CalloutEngine.driftEvent(delta: -12, isOnTime: false) == .drift(seconds: 12, relation: .early))
        #expect(CalloutEngine.driftEvent(delta: 72, isOnTime: false) == .drift(seconds: 72, relation: .late))
        #expect(CalloutEngine.driftEvent(delta: 4, isOnTime: true) == .drift(seconds: 4, relation: .onTime))
        #expect(CalloutEngine.driftEvent(delta: 0.4, isOnTime: false) == .drift(seconds: 0, relation: .onTime))
    }

    @Test("Codable raw values are pinned (payload contract)")
    func pinnedRawValues() throws {
        #expect(TurnToTarget.Direction.left.rawValue == "left")
        #expect(TurnToTarget.Direction.right.rawValue == "right")
        #expect(CueHaptic.allCases.map(\.rawValue) == ["notification", "directionUp", "directionDown", "success",
                                                       "failure", "retry", "start", "stop", "click"])
        let json = try #require(String(data: JSONEncoder().encode(Callout.Event.turnIn(.left)), encoding: .utf8))
        #expect(json == #"{"turnIn":{"_0":"left"}}"#)
    }
}
