import Foundation
import Testing
@testable import FormationFlightCore

/// The phone-to-mirror payload: local ticking, staleness and the versioned codec.
@Suite("FlightSnapshot")
struct FlightSnapshotTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A live snapshot sent at `start`: 1000 m out at 10 m/s, no geometry, ToT in 100 s.
    private func snapshot(sentAt: Date = start,
                          tot: Date? = start.addingTimeInterval(100),
                          fixTime: Date? = start,
                          groundSpeed: Double? = 10,
                          track: Double? = nil,
                          bearing: Double? = nil,
                          turnDirection: TurnToTarget.Direction? = nil,
                          isFixStale: Bool = false) -> FlightSnapshot {
        FlightSnapshot(sentAt: sentAt, missionName: "RAZOR 1", missionType: .tot, tot: tot,
                       hackTime: nil, isHackPending: false, fixTime: fixTime, distance: 1000,
                       groundSpeed: groundSpeed, track: track, bearing: bearing,
                       turnDirection: turnDirection, isFixStale: isFixStale,
                       yellowTolerance: 5, redTolerance: 10, speedUnit: .kts, distanceUnit: .nm)
    }

    // MARK: - Local ticking

    @Test("At the send time the receiver computes what the phone's TimingEngine does")
    func timingMatchesEngine() {
        let s = snapshot(track: 0, bearing: 90, turnDirection: .left)
        let expected = TimingEngine.compute(TimingEngine.Input(
            now: Self.start, tot: s.tot, distance: 1000, groundSpeed: 10, track: 0, bearing: 90,
            preferredTurnDirection: .left, yellowTolerance: 5, redTolerance: 10))
        #expect(s.timing(at: Self.start) == expected)
    }

    @Test("Between messages the receiver ticks on its own clock")
    func ticksLocally() {
        let s = snapshot()
        let first = s.timing(at: Self.start)
        let later = s.timing(at: Self.start.addingTimeInterval(3.6))
        #expect(first.ete == 100)
        #expect(first.delta == 0)
        #expect(later.currentTime == Self.start.addingTimeInterval(3))
        #expect(later.timeToToT == 97)
        // Same fix inputs, three seconds on: ETA moves with the clock, so Δ drifts late.
        #expect(later.eta == Self.start.addingTimeInterval(103))
        #expect(later.delta == 3)
    }

    // MARK: - Staleness

    @Test("Fresh up to and including the threshold since the send; stale just after")
    func staleAfterSendGap() {
        let s = snapshot(fixTime: nil)
        #expect(!s.isStale(at: Self.start))
        #expect(!s.isStale(at: Self.start.addingTimeInterval(TimingEngine.staleFixThreshold)))
        #expect(s.isStale(at: Self.start.addingTimeInterval(TimingEngine.staleFixThreshold + 0.001)))
    }

    @Test("A fix that ages past the threshold is stale even while snapshots keep arriving")
    func staleFixAge() {
        let fix = Self.start.addingTimeInterval(-10)
        let s = snapshot(fixTime: fix)
        #expect(!s.isStale(at: fix.addingTimeInterval(15)))
        #expect(s.isStale(at: fix.addingTimeInterval(15.5)))
    }

    @Test("The phone's own stale verdict is honoured immediately")
    func phoneSaidStale() {
        #expect(snapshot(isFixStale: true).isStale(at: Self.start))
    }

    @Test("No fix yet is not stale on its own")
    func noFixNotStale() {
        #expect(!snapshot(fixTime: nil, groundSpeed: nil).isStale(at: Self.start.addingTimeInterval(5)))
    }

    @Test("When stale, speed-derived readouts blank but the ToT countdown keeps going (B-07)")
    func staleTimingBlanks() {
        let s = snapshot(track: 0, bearing: 90, turnDirection: .right)
        let out = s.timing(at: Self.start.addingTimeInterval(20))
        #expect(out.ete == nil)
        #expect(out.eta == nil)
        #expect(out.delta == nil)
        #expect(out.status == .unknown)
        #expect(out.turnInDirection == nil)
        #expect(out.timeToToT == 80)
        // Distance and bearing are kept, so required speed is still offered.
        #expect(out.requiredGroundSpeed != nil)
    }

    // MARK: - Codec

    @Test("Round-trips exactly through the codec")
    func roundTrip() throws {
        var s = snapshot(sentAt: Self.start.addingTimeInterval(0.123456), track: 12.5, bearing: 270.25,
                         turnDirection: .left)
        s.missionType = .hackTime
        s.hackTime = 90
        s.isHackPending = true
        s.tot = nil
        s.speedUnit = .mph
        s.distanceUnit = .km
        s.isEnded = true
        let decoded = try FlightSnapshot(data: s.encoded())
        #expect(decoded == s)
    }

    @Test("All-nil optionals round-trip")
    func roundTripNils() throws {
        let s = snapshot(tot: nil, fixTime: nil, groundSpeed: nil)
        #expect(try FlightSnapshot(data: s.encoded()) == s)
    }

    @Test("A payload from another version is rejected with a version error")
    func versionMismatch() throws {
        var s = snapshot()
        s.version = CorePayload.version + 1
        let data = try s.encoded()
        #expect(throws: FlightSnapshot.CodecError.unsupportedVersion(found: CorePayload.version + 1,
                                                                      expected: CorePayload.version)) {
            try FlightSnapshot(data: data)
        }
    }

    @Test("Garbage and version-less payloads fail to decode")
    func garbage() {
        #expect(throws: (any Error).self) { try FlightSnapshot(data: Data("nope".utf8)) }
        #expect(throws: (any Error).self) { try FlightSnapshot(data: Data(#"{"missionName":"x"}"#.utf8)) }
    }

    @Test("New snapshots carry the current payload version")
    func defaultVersion() {
        #expect(snapshot().version == CorePayload.version)
    }
}
