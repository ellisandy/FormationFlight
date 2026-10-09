import Foundation
import Testing
@testable import FormationFlightCore

/// Status boundaries for yellow 5 / red 10. File scope because `@Test(arguments:)` is
/// evaluated outside the suite.
private let statusCases: [(delta: TimeInterval?, expected: TimingStatus)] = [
    (0, .good), (5, .good), (6, .bad), (10, .bad), (11, .reallyBad),
    (-5, .good), (-6, .bad), (-10, .bad), (-11, .reallyBad), (nil, .unknown),
]

/// B-40: raw `distance / speed` at 10 m/s and the whole-second ETE it must truncate to.
private let eteTruncationCases: [(distance: Double, ete: TimeInterval)] = [
    (9, 0), (595, 59), (1004, 100), (100, 10),
]

/// The pure timing math behind the flight screen (B-24, B-25, B-40, B-42, B-46).
@Suite("TimingEngine")
struct TimingEngineTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func input(now: Date = start,
                       tot: Date? = nil,
                       distance: Double? = nil,
                       groundSpeed: Double? = nil,
                       track: Double? = nil,
                       bearing: Double? = nil,
                       preferred: TurnToTarget.Direction? = nil,
                       yellow: Int = 5,
                       red: Int = 10) -> TimingEngine.Input {
        TimingEngine.Input(now: now, tot: tot, distance: distance, groundSpeed: groundSpeed,
                           track: track, bearing: bearing, preferredTurnDirection: preferred,
                           yellowTolerance: yellow, redTolerance: red)
    }

    // MARK: - Clock and ETE

    @Test("The clock is floored to the whole second (B-40)")
    func clockFloored() {
        let out = TimingEngine.compute(input(now: Self.start.addingTimeInterval(0.999)))
        #expect(out.currentTime == Self.start)
    }

    @Test("Direct-to ETE truncates, never rounds (B-40)", arguments: eteTruncationCases)
    func eteTruncation(distance: Double, ete: TimeInterval) {
        let out = TimingEngine.compute(input(distance: distance, groundSpeed: 10))
        #expect(out.ete == ete)
        #expect(out.eta == Self.start.addingTimeInterval(ete))
    }

    @Test("Time + ETE == ETA even with a fractional clock")
    func etaFromFlooredValues() {
        let out = TimingEngine.compute(input(now: Self.start.addingTimeInterval(0.7), distance: 1004, groundSpeed: 10))
        #expect(out.eta == out.currentTime.addingTimeInterval(100))
    }

    @Test("No speed, zero speed or no distance: no ETE, ETA, delta, and unknown status")
    func missingInputs() {
        let tot = Self.start.addingTimeInterval(100)
        for out in [TimingEngine.compute(input(tot: tot, distance: 1000)),
                    TimingEngine.compute(input(tot: tot, distance: 1000, groundSpeed: 0)),
                    TimingEngine.compute(input(tot: tot, groundSpeed: 10))] {
            #expect(out.ete == nil)
            #expect(out.eta == nil)
            #expect(out.delta == nil)
            #expect(out.status == .unknown)
            #expect(out.turnDuration == nil)
            #expect(out.turnInDirection == nil)
            #expect(out.turnRemaining == nil)
        }
    }

    // MARK: - Delta and status

    @Test("Status from |Δ| against the tolerances", arguments: statusCases)
    func status(delta: TimeInterval?, expected: TimingStatus) {
        #expect(TimingStatus(delta: delta, yellowTolerance: 5, redTolerance: 10) == expected)
        if let delta {
            // ETE 10 s at 10 m/s over 100 m, ToT placed so ETA − ToT == delta.
            let tot = Self.start.addingTimeInterval(10 - delta)
            let out = TimingEngine.compute(input(tot: tot, distance: 100, groundSpeed: 10))
            #expect(out.delta == delta)
            #expect(out.status == expected)
        }
    }

    @Test("A sub-second miss is a zero delta, not LATE +0 (B-46)")
    func deltaTruncatesTowardZero() {
        let late = TimingEngine.compute(input(tot: Self.start.addingTimeInterval(9.4), distance: 100, groundSpeed: 10))
        #expect(late.delta == 0)
        let early = TimingEngine.compute(input(tot: Self.start.addingTimeInterval(11.6), distance: 100, groundSpeed: 10))
        #expect(early.delta == -1)
    }

    @Test("Surplus orbits count whole two-minute circles of earliness")
    func surplusOrbits() {
        let tot = Self.start.addingTimeInterval(10 + 250)
        #expect(TimingEngine.compute(input(tot: tot, distance: 100, groundSpeed: 10)).surplusOrbits == 2)
        #expect(TimingEngine.compute(input(tot: Self.start, distance: 100, groundSpeed: 10)).surplusOrbits == 0)
        #expect(TimingEngine.compute(input(distance: 100, groundSpeed: 10)).surplusOrbits == 0)
    }

    @Test("Time to ToT is from the floored clock and goes negative after ToT")
    func timeToToT() {
        let now = Self.start.addingTimeInterval(0.5)
        #expect(TimingEngine.compute(input(now: now, tot: Self.start.addingTimeInterval(30))).timeToToT == 30)
        #expect(TimingEngine.compute(input(now: now, tot: Self.start.addingTimeInterval(-4))).timeToToT == -4)
        #expect(TimingEngine.compute(input(now: now)).timeToToT == nil)
    }

    // MARK: - Required ground speed

    @Test("Required ground speed is direct-to without geometry and needs time left (B-24)")
    func requiredGroundSpeedDirect() {
        let out = TimingEngine.compute(input(tot: Self.start.addingTimeInterval(100), distance: 5000))
        #expect(out.requiredGroundSpeed == 50)
        #expect(TimingEngine.compute(input(tot: Self.start, distance: 5000)).requiredGroundSpeed == nil)
        #expect(TimingEngine.compute(input(tot: Self.start.addingTimeInterval(-5), distance: 5000)).requiredGroundSpeed == nil)
        #expect(TimingEngine.compute(input(tot: Self.start.addingTimeInterval(100))).requiredGroundSpeed == nil)
    }

    @Test("Turn-aware required ground speed matches TurnToTarget (B-25)")
    func requiredGroundSpeedTurnAware() throws {
        let out = TimingEngine.compute(input(tot: Self.start.addingTimeInterval(200), distance: 8000,
                                             track: 0, bearing: 90))
        let expected = try #require(TurnToTarget.requiredGroundSpeed(distance: 8000, bearing: 90, track: 0,
                                                                    timeRemaining: 200))
        #expect(out.requiredGroundSpeed == expected)
    }

    // MARK: - Turn-aware ETE

    @Test("With track and bearing, ETE includes the turn and reports its caption inputs (B-25, B-45)")
    func turnAwareETE() throws {
        let out = TimingEngine.compute(input(distance: 8000, groundSpeed: 100, track: 0, bearing: 90))
        let s = try #require(TurnToTarget.solve(distance: 8000, bearing: 90, track: 0, groundSpeed: 100))
        #expect(out.ete == s.totalTime.rounded(.down))
        #expect(out.turnDuration == s.turnDuration.rounded(.down))
        #expect(out.turnInDirection == .right)
        #expect(out.turnRemaining == s.turnDuration)
    }

    @Test("The orbit in progress is continued rather than reversed")
    func preferredDirectionContinued() {
        let out = TimingEngine.compute(input(distance: 8000, groundSpeed: 100, track: 0, bearing: 60, preferred: .left))
        #expect(out.turnInDirection == .left)
    }

    @Test("Already pointed at the target: no turn caption, turn remaining near zero")
    func alignedNoCaption() throws {
        let out = TimingEngine.compute(input(distance: 1005, groundSpeed: 100, track: 45, bearing: 45))
        #expect(out.ete == 10)
        #expect(out.turnDuration == nil)
        #expect(out.turnInDirection == nil)
        let remaining = try #require(out.turnRemaining)
        #expect(remaining < 1)
    }

    @Test("An invalid track (Core Location's -1) or bearing falls back to direct-to")
    func invalidGeometryIsDirect() {
        for (track, bearing) in [(-1.0, 90.0), (0, -1), (.nan, 90), (0, .infinity)] {
            let out = TimingEngine.compute(input(distance: 8000, groundSpeed: 100, track: track, bearing: bearing))
            #expect(out.ete == 80)
            #expect(out.turnDuration == nil)
            #expect(out.turnRemaining == nil)
        }
    }

    // MARK: - Staleness

    @Test("A fix is stale only once strictly older than the threshold (B-07)")
    func fixStaleness() {
        let fix = Self.start
        #expect(TimingEngine.staleFixThreshold == 15)
        #expect(!TimingEngine.isFixStale(lastFix: nil, now: fix))
        #expect(!TimingEngine.isFixStale(lastFix: fix, now: fix.addingTimeInterval(15)))
        #expect(TimingEngine.isFixStale(lastFix: fix, now: fix.addingTimeInterval(15.001)))
    }

    @Test("TimingStatus raw values are pinned (payload contract)")
    func statusRawValues() throws {
        #expect(TimingStatus.allCases.map(\.rawValue) == ["good", "bad", "reallyBad", "unknown"])
        let data = try JSONEncoder().encode(TimingStatus.reallyBad)
        #expect(try JSONDecoder().decode(TimingStatus.self, from: data) == .reallyBad)
    }
}
