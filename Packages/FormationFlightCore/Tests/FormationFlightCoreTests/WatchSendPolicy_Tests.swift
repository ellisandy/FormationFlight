import Foundation
import Testing
@testable import FormationFlightCore

/// When the phone refreshes the watch's application context (F-02).
@Suite("WatchSendPolicy")
struct WatchSendPolicyTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Sent `offset` s after `start`, closing at 10 m/s so Δ stays put: ETE 100 s, ToT at 100 s.
    private func snapshot(at offset: TimeInterval = 0) -> FlightSnapshot {
        let sentAt = Self.start.addingTimeInterval(offset)
        return FlightSnapshot(sentAt: sentAt, missionName: "RAZOR 1", missionType: .tot,
                              tot: Self.start.addingTimeInterval(100), hackTime: nil,
                              isHackPending: false, fixTime: sentAt, distance: 1000 - 10 * offset,
                              groundSpeed: 10, track: nil, bearing: nil, turnDirection: nil,
                              isFixStale: false, yellowTolerance: 5, redTolerance: 10,
                              speedUnit: .kts, distanceUnit: .nm)
    }

    @Test("Messages go only to a reachable watch")
    func messagesNeedReachability() {
        #expect(WatchSendPolicy.shouldSendMessage(isReachable: true))
        #expect(!WatchSendPolicy.shouldSendMessage(isReachable: false))
    }

    @Test("The first snapshot always becomes the context")
    func first() {
        #expect(WatchSendPolicy.shouldUpdateContext(previous: nil, next: snapshot(), lastSentAt: nil))
    }

    @Test("With nothing visible changing, the context is refreshed only on the keep-alive")
    func keepAlive() {
        let first = snapshot()
        for offset in 1..<Int(WatchSendPolicy.contextKeepAliveInterval) {
            #expect(!WatchSendPolicy.shouldUpdateContext(previous: first, next: snapshot(at: TimeInterval(offset)),
                                                         lastSentAt: Self.start))
        }
        #expect(WatchSendPolicy.shouldUpdateContext(previous: first,
                                                    next: snapshot(at: WatchSendPolicy.contextKeepAliveInterval),
                                                    lastSentAt: Self.start))
    }

    @Test("The ended snapshot is always sent")
    func ended() {
        var end = snapshot(at: 1)
        end.isEnded = true
        #expect(WatchSendPolicy.shouldUpdateContext(previous: snapshot(), next: end, lastSentAt: Self.start))
    }

    @Test("Visible changes are sent at once")
    func visibleChanges() {
        let base = snapshot()
        var changes: [FlightSnapshot] = []
        var s = snapshot(at: 1); s.tot = s.tot?.addingTimeInterval(30); changes.append(s)
        s = snapshot(at: 1); s.isHackPending = true; changes.append(s)
        s = snapshot(at: 1); s.isFixStale = true; changes.append(s)
        s = snapshot(at: 1); s.missionName = "VIPER"; changes.append(s)
        s = snapshot(at: 1); s.speedUnit = .mph; changes.append(s)
        s = snapshot(at: 1); s.redTolerance = 20; changes.append(s)
        s = snapshot(at: 1); s.turnDirection = .right; changes.append(s)
        s = snapshot(at: 1); s.groundSpeed = nil; changes.append(s)
        // Slowing to 8 m/s: ETE 124 s at 1 s, Δ +25 s, beyond red.
        s = snapshot(at: 1); s.groundSpeed = 8; changes.append(s)
        for next in changes {
            #expect(WatchSendPolicy.changesVisibly(from: base, to: next))
            #expect(WatchSendPolicy.shouldUpdateContext(previous: base, next: next, lastSentAt: Self.start))
        }
    }

    @Test("Distance and speed moving within the same status band is not a visible change")
    func noiseIsNotVisible() {
        var next = snapshot(at: 1)
        next.groundSpeed = 10.1
        #expect(!WatchSendPolicy.changesVisibly(from: snapshot(), to: next))
    }
}
