import Foundation
import Testing
@testable import Formation_Flight

/// F-01 callout rules, driven one simulated 1 Hz tick at a time.
@Suite("CalloutEngine")
struct CalloutEngineTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Default input: ToT far away, on time, straight, no speeds, fresh fix.
    private func input(at second: Int,
                       tot: Date? = nil,
                       delta: TimeInterval? = 0,
                       turnDirection: TurnToTarget.Direction? = nil,
                       turnInDirection: TurnToTarget.Direction? = nil,
                       turnRemaining: TimeInterval? = nil,
                       currentKnots: Double? = nil,
                       requiredKnots: Double? = nil,
                       isFixStale: Bool = false,
                       settings: CalloutSettings = .defaults,
                       speedUnit: Settings.SpeedUnit = .kts) -> CalloutEngine.Input {
        CalloutEngine.Input(
            now: Self.start.addingTimeInterval(TimeInterval(second)),
            tot: tot,
            delta: delta,
            yellowTolerance: 10,
            redTolerance: 30,
            turnDirection: turnDirection,
            turnInDirection: turnInDirection,
            turnRemaining: turnRemaining,
            currentGroundSpeed: currentKnots.map { Measurement(value: $0, unit: .knots) },
            requiredGroundSpeed: requiredKnots.map { Measurement(value: $0, unit: .knots) },
            isFixStale: isFixStale,
            settings: settings,
            speedUnit: speedUnit
        )
    }

    /// Runs `seconds` ticks and returns the callouts by tick.
    private func run(_ engine: inout CalloutEngine, _ seconds: ClosedRange<Int>,
                     _ make: (Int) -> CalloutEngine.Input) -> [(second: Int, callout: Callout)] {
        seconds.compactMap { second in engine.evaluate(make(second)).map { (second, $0) } }
    }

    // MARK: - Countdown

    @Test("Countdown calls each mark once, in order, ending with Mark at ToT")
    func countdownMarks() {
        var engine = CalloutEngine()
        let tot = Self.start.addingTimeInterval(305)
        let out = run(&engine, 0...320) { input(at: $0, tot: tot) }
        #expect(out.map(\.callout.text) == ["Five minutes.", "One minute.", "Thirty seconds.", "Ten.",
                                            "5.", "4.", "3.", "2.", "1.", "Mark."])
        #expect(out.map(\.second) == [5, 245, 275, 295, 300, 301, 302, 303, 304, 305])
        #expect(out.allSatisfy { $0.callout.kind == .countdown })
    }

    @Test("Moving the ToT past a mark does not replay it")
    func totEditSkipsPassedMarks() {
        var engine = CalloutEngine()
        _ = engine.evaluate(input(at: 0, tot: Self.start.addingTimeInterval(100)))
        // ToT pulled in: 45 s left now, so "One minute" was skipped rather than late.
        #expect(engine.evaluate(input(at: 1, tot: Self.start.addingTimeInterval(46))) == nil)
    }

    @Test("Countdown off gives no countdown")
    func countdownDisabled() {
        var engine = CalloutEngine()
        var settings = CalloutSettings.defaults
        settings.countdownEnabled = false
        let tot = Self.start.addingTimeInterval(65)
        #expect(run(&engine, 0...70) { input(at: $0, tot: tot, settings: settings) }.isEmpty)
    }

    // MARK: - Drift

    @Test("A first on-time reading is silent; leaving tolerance is announced after the hold")
    func driftHoldAndFirstReading() {
        var engine = CalloutEngine()
        let out = run(&engine, 0...20) { second in input(at: second, delta: second < 10 ? 0 : 15) }
        #expect(out.map(\.second) == [13])
        #expect(out.first?.callout.text == "Late, 15.")
    }

    @Test("A band change shorter than the hold is not announced")
    func driftFlapIsSilent() {
        var engine = CalloutEngine()
        let out = run(&engine, 0...30) { second in input(at: second, delta: (10...11).contains(second) ? 15 : 0) }
        #expect(out.isEmpty)
    }

    @Test("Drift waits out the cooldown, then reports the current band")
    func driftCooldown() {
        var engine = CalloutEngine()
        // Early red from the start, then on time from t = 5.
        let out = run(&engine, 0...30) { second in input(at: second, delta: second < 5 ? -45 : 0) }
        #expect(out.map(\.second) == [3, 18])
        #expect(out.map(\.callout.text) == ["Early, 45.", "On time."])
    }

    @Test("Minutes are spelled out past 60 s")
    func driftMinutes() {
        #expect(CalloutEngine.driftText(delta: 72, isOnTime: false) == "Late, 1 minute, 12 seconds.")
        #expect(CalloutEngine.driftText(delta: -12, isOnTime: false) == "Early, 12.")
        #expect(CalloutEngine.driftText(delta: 4, isOnTime: true) == "On time.")
    }

    @Test("Advisories wait for the gap after a countdown call")
    func advisoryGapAfterCountdown() {
        var engine = CalloutEngine()
        let tot = Self.start.addingTimeInterval(64)
        // "One minute" at t = 4; drift band became late at t = 0, held by t = 3, but the
        // countdown wins t = 4 and drift then waits until t = 9.
        let out = run(&engine, 0...12) { input(at: $0, tot: tot, delta: $0 < 1 ? 0 : 20) }
        #expect(out.map(\.second) == [4, 9])
        #expect(out.map(\.callout.text) == ["One minute.", "Late, 20."])
    }

    @Test("Only the countdown speaks in the final run, and nothing but GPS after ToT")
    func finalRunSuppression() {
        var engine = CalloutEngine()
        let tot = Self.start.addingTimeInterval(20)
        let out = run(&engine, 0...40) { second in input(at: second, tot: tot, delta: second < 8 ? 0 : 25) }
        #expect(out.allSatisfy { $0.callout.kind == .countdown })
    }

    // MARK: - Speed

    @Test("Speed advice needs Δ outside yellow, holds, and does not repeat an unchanged target")
    func speedAdvice() {
        var engine = CalloutEngine()
        var settings = CalloutSettings.defaults
        settings.driftEnabled = false
        let out = run(&engine, 0...100) { second in
            input(at: second, delta: second < 20 ? 5 : 20, currentKnots: 120, requiredKnots: 140, settings: settings)
        }
        // Gap held since t = 0, but on time until t = 20.
        #expect(out.map(\.second) == [20])
        #expect(out.first?.callout.text == "Increase, 140.")
    }

    @Test("Speed advice is in the pilot's unit and re-announced when the target moves")
    func speedAdviceUnitAndRepeat() {
        var engine = CalloutEngine()
        var settings = CalloutSettings.defaults
        settings.driftEnabled = false
        let out = run(&engine, 0...60) { second in
            input(at: second, delta: 40, currentKnots: 120, requiredKnots: second < 30 ? 100 : 80,
                  settings: settings, speedUnit: .mph)
        }
        #expect(out.map(\.second) == [3, 33])
        #expect(out.map(\.callout.text) == ["Reduce, 115.", "Reduce, 92."])
    }

    @Test("A gap under the threshold gives no advice")
    func speedUnderThreshold() {
        var engine = CalloutEngine()
        #expect(run(&engine, 0...20) { input(at: $0, delta: 40, currentKnots: 120, requiredKnots: 129) }
            .allSatisfy { $0.callout.kind != .speed })
    }

    // MARK: - GPS

    @Test("GPS lost and restored are each announced once")
    func gpsLostRestored() {
        var engine = CalloutEngine()
        let out = run(&engine, 0...30) { second in input(at: second, isFixStale: (5..<20).contains(second)) }
        #expect(out.map(\.callout.text) == ["GPS lost.", "GPS restored."])
        #expect(out.map(\.second) == [5, 20])
    }

    @Test("Restored is not announced when the loss was not")
    func gpsRestoredNeedsLost() {
        var engine = CalloutEngine()
        var off = CalloutSettings.defaults
        off.speedAndGPSEnabled = false
        let out = run(&engine, 0...30) { second in
            input(at: second, isFixStale: (5..<20).contains(second), settings: second < 15 ? off : .defaults)
        }
        #expect(out.isEmpty)
    }

    // MARK: - Turn cues

    @Test("Straight and early, the turn cue fires when turning in now comes on time, without a drift echo")
    func startTurnCue() {
        var engine = CalloutEngine()
        var settings = CalloutSettings.defaults
        settings.driftEnabled = true
        // Early 40 s shrinking by 2 s per second along a racetrack leg.
        let out = run(&engine, 0...40) { second in
            input(at: second, delta: -40 + 2 * Double(second), turnInDirection: .right, turnRemaining: 60, settings: settings)
        }
        let turn = out.filter { $0.callout.kind == .turnIn }
        #expect(turn.map(\.second) == [15])
        #expect(turn.first?.callout.text == "Turn right now.")
        #expect(!out.contains { $0.callout.text == "On time." })
    }

    @Test("While orbiting, Roll out fires once near the target when no orbit is spare")
    func rollOutCue() {
        var engine = CalloutEngine()
        // Turn left counts down 30 → 0, then wraps to 120 (passed the target).
        let out = run(&engine, 0...40) { second in
            let remaining = second <= 30 ? Double(30 - second) : Double(150 - second)
            return input(at: second, delta: -20, turnDirection: .left, turnInDirection: .left, turnRemaining: remaining)
        }
        let turn = out.filter { $0.callout.kind == .turnIn }
        #expect(turn.map(\.second) == [27])
        #expect(turn.first?.callout.text == "Roll out now.")
    }

    @Test("No roll-out cue while a full orbit still fits")
    func rollOutWithSpareOrbit() {
        var engine = CalloutEngine()
        let out = run(&engine, 0...30) { second in
            input(at: second, delta: -150, turnDirection: .left, turnInDirection: .left, turnRemaining: Double(30 - second))
        }
        #expect(!out.contains { $0.callout.kind == .turnIn })
    }
}
