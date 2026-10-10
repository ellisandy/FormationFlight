import Foundation
import Testing
@testable import FormationFlightCore

/// The Live Activity content mapping and its update / stale policy (F-02).
@Suite("FlightActivityContent")
struct FlightActivityContentTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// 1000 m out at 10 m/s, no geometry: ETE 100 s. ToT `totOffset` s after `sentAt`.
    private func snapshot(sentAt: Date = start,
                          totOffset: TimeInterval? = 100,
                          missionType: MissionType = .tot,
                          isHackPending: Bool = false,
                          fixTime: Date? = start,
                          groundSpeed: Double? = 10,
                          isFixStale: Bool = false) -> FlightSnapshot {
        FlightSnapshot(sentAt: sentAt, missionName: "RAZOR 1", missionType: missionType,
                       tot: totOffset.map { Self.start.addingTimeInterval($0) },
                       hackTime: nil, isHackPending: isHackPending, fixTime: fixTime, distance: 1000,
                       groundSpeed: groundSpeed, track: nil, bearing: nil, turnDirection: nil,
                       isFixStale: isFixStale, yellowTolerance: 5, redTolerance: 10,
                       speedUnit: .kts, distanceUnit: .nm)
    }

    // MARK: - Mapping

    @Test("Content carries the readouts the phone computes for the same tick")
    func mapsTiming() {
        let s = snapshot(totOffset: 93)
        let content = FlightActivityContent(snapshot: s)
        let timing = s.timing(at: Self.start)
        #expect(content.tot == s.tot)
        #expect(content.eta == timing.eta)
        #expect(content.delta == 7)
        #expect(content.status == .bad)
        #expect(content.deltaRelation == .late)
        #expect(content.updatedAt == Self.start)
        #expect(content.isFixStale == false)
        #expect(content.isHackPending == false)
    }

    @Test("EARLY / LATE / ON TIME follow the sign of Δ, nil without Δ")
    func deltaRelation() {
        #expect(FlightActivityContent(snapshot: snapshot(totOffset: 110)).deltaRelation == .early)
        #expect(FlightActivityContent(snapshot: snapshot(totOffset: 100)).deltaRelation == .onTime)
        #expect(FlightActivityContent(snapshot: snapshot(totOffset: 90)).deltaRelation == .late)
        #expect(FlightActivityContent(snapshot: snapshot(groundSpeed: nil)).deltaRelation == nil)
    }

    @Test("A hack pending has no ToT to count to")
    func hackPending() {
        let content = FlightActivityContent(snapshot: snapshot(totOffset: nil, missionType: .hackTime,
                                                               isHackPending: true))
        #expect(content.isHackPending)
        #expect(content.tot == nil)
        #expect(content.delta == nil)
        #expect(content.status == .unknown)
    }

    @Test("A stale fix blanks Δ and is flagged for the STALE treatment")
    func staleFix() {
        let phoneSaidStale = FlightActivityContent(snapshot: snapshot(isFixStale: true))
        #expect(phoneSaidStale.isFixStale)
        #expect(phoneSaidStale.delta == nil)
        #expect(phoneSaidStale.eta == nil)
        #expect(phoneSaidStale.status == .unknown)
        #expect(phoneSaidStale.tot != nil)

        // Fix aged past the threshold by the send time, even if the flag was not set.
        let aged = FlightActivityContent(snapshot: snapshot(fixTime: Self.start.addingTimeInterval(-16)))
        #expect(aged.isFixStale)
        #expect(aged.delta == nil)
    }

    @Test("A recent cue is kept, an old one dropped")
    func cueWindow() {
        let cueAt = Self.start
        let fresh = FlightActivityContent(snapshot: snapshot(sentAt: Self.start.addingTimeInterval(9)),
                                          cue: .gpsLost, cueAt: cueAt)
        #expect(fresh.cue == .gpsLost)
        #expect(fresh.cueAt == cueAt)

        let old = FlightActivityContent(snapshot: snapshot(sentAt: Self.start.addingTimeInterval(10)),
                                        cue: .gpsLost, cueAt: cueAt)
        #expect(old.cue == nil)
        #expect(old.cueAt == nil)
    }

    @Test("Content survives a Codable round trip (it crosses into the widget extension)")
    func codableRoundTrip() throws {
        let content = FlightActivityContent(snapshot: snapshot(), cue: .speed(increase: true, target: 140, unit: .kts),
                                            cueAt: Self.start)
        let data = try JSONEncoder().encode(content)
        #expect(try JSONDecoder().decode(FlightActivityContent.self, from: data) == content)
    }

    // MARK: - Update policy

    private func content(delta: Int? = 0,
                         eta: TimeInterval? = 100,
                         status: TimingStatus = .good,
                         cue: Callout.Event? = nil,
                         isFixStale: Bool = false,
                         isHackPending: Bool = false,
                         at offset: TimeInterval = 0) -> FlightActivityContent {
        FlightActivityContent(tot: Self.start.addingTimeInterval(100),
                              eta: eta.map { Self.start.addingTimeInterval($0) },
                              delta: delta, status: status, isHackPending: isHackPending,
                              cue: cue, cueAt: cue == nil ? nil : Self.start,
                              updatedAt: Self.start.addingTimeInterval(offset), isFixStale: isFixStale)
    }

    @Test("The first content is always sent")
    func firstIsSent() {
        #expect(LiveActivityPolicy.shouldUpdate(previous: nil, next: content(), lastSentAt: nil, now: Self.start))
    }

    @Test("Nothing visible changed: held back until the keep-alive is due")
    func keepAlive() {
        let sent = content()
        let lastSentAt = Self.start
        for offset in 1..<5 {
            let now = Self.start.addingTimeInterval(TimeInterval(offset))
            #expect(!LiveActivityPolicy.shouldUpdate(previous: sent, next: content(at: TimeInterval(offset)),
                                                     lastSentAt: lastSentAt, now: now))
        }
        #expect(LiveActivityPolicy.shouldUpdate(previous: sent, next: content(at: 5), lastSentAt: lastSentAt,
                                                now: Self.start.addingTimeInterval(LiveActivityPolicy.keepAliveInterval)))
    }

    @Test("Any visible change is sent at once",
          arguments: Change.allCases)
    func visibleChange(_ change: Change) {
        let sent = content()
        let next: FlightActivityContent
        switch change {
        case .delta: next = content(delta: 1, at: 1)
        case .status: next = content(status: .bad, at: 1)
        case .cue: next = content(cue: .countdown(secondsToToT: 10), at: 1)
        case .stale: next = content(isFixStale: true, at: 1)
        case .hack: next = content(isHackPending: true, at: 1)
        case .etaJump: next = content(eta: 102, at: 1)
        case .etaLost: next = content(eta: nil, at: 1)
        }
        #expect(LiveActivityPolicy.shouldUpdate(previous: sent, next: next, lastSentAt: Self.start,
                                                now: Self.start.addingTimeInterval(1)))
    }

    enum Change: CaseIterable, Sendable { case delta, status, cue, stale, hack, etaJump, etaLost }

    @Test("A one-second ETA wobble alone does not force an update")
    func etaWobble() {
        #expect(!LiveActivityPolicy.shouldUpdate(previous: content(), next: content(eta: 101, at: 1),
                                                 lastSentAt: Self.start, now: Self.start.addingTimeInterval(1)))
    }

    @Test("The stale date is twice the fix threshold after the content was built")
    func staleDate() {
        let c = content(at: 7)
        #expect(LiveActivityPolicy.staleAfter == 2 * TimingEngine.staleFixThreshold)
        #expect(LiveActivityPolicy.staleDate(for: c) == Self.start.addingTimeInterval(7 + 30))
        // Several keep-alives fit before the stale date, so a foreground app never trips it.
        #expect(LiveActivityPolicy.staleAfter >= 3 * LiveActivityPolicy.keepAliveInterval)
    }
}
