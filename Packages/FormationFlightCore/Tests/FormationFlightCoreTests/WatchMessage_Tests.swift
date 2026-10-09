import Foundation
import Testing
@testable import FormationFlightCore

/// The phone-to-watch wire format (F-02).
@Suite("WatchMessage")
struct WatchMessageTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000.25)

    private func snapshot() -> FlightSnapshot {
        FlightSnapshot(sentAt: Self.start, missionName: "RAZOR 1", missionType: .tot,
                       tot: Self.start.addingTimeInterval(100), hackTime: nil, isHackPending: false,
                       fixTime: Self.start, distance: 1000, groundSpeed: 10, track: 12, bearing: 90,
                       turnDirection: .left, isFixStale: false, yellowTolerance: 5, redTolerance: 10,
                       speedUnit: .kts, distanceUnit: .nm)
    }

    @Test("A snapshot round-trips through the WatchConnectivity dictionary")
    func snapshotRoundTrip() throws {
        let message = WatchMessage.snapshot(snapshot())
        let dictionary = try message.transferDictionary()
        #expect(dictionary.keys.sorted() == [WatchMessage.payloadKey])
        #expect(dictionary[WatchMessage.payloadKey] is Data)
        #expect(try WatchMessage(transferDictionary: dictionary) == message)
    }

    @Test("A callout round-trips with its emission time", arguments: [
        Callout.Event.countdown(secondsToToT: 10),
        .turnIn(.right),
        .rollOut,
        .drift(seconds: 65, relation: .late),
        .speed(increase: false, target: 240, unit: .kph),
        .gpsLost,
    ])
    func calloutRoundTrip(event: Callout.Event) throws {
        let message = WatchMessage.callout(Callout(event), emittedAt: Self.start)
        #expect(try WatchMessage(data: message.encoded()) == message)
    }

    @Test("A dictionary without our key is rejected as missing")
    func missingPayload() {
        #expect(throws: WatchMessage.CodecError.missingPayload) {
            try WatchMessage(transferDictionary: [:])
        }
        #expect(throws: WatchMessage.CodecError.missingPayload) {
            try WatchMessage(transferDictionary: [WatchMessage.payloadKey: "not data"])
        }
    }

    @Test("A message from another payload version is rejected before decoding")
    func otherVersion() throws {
        let json = #"{"version":99,"somethingNew":true}"#
        #expect(throws: WatchMessage.CodecError.unsupportedVersion(found: 99, expected: CorePayload.version)) {
            try WatchMessage(data: Data(json.utf8))
        }
    }

    @Test("A snapshot of another version inside a current envelope is rejected")
    func otherSnapshotVersion() throws {
        var s = snapshot()
        s.version = 99
        let data = try WatchMessage.snapshot(s).encoded()
        #expect(throws: WatchMessage.CodecError.unsupportedVersion(found: 99, expected: CorePayload.version)) {
            try WatchMessage(data: data)
        }
    }

    @Test("A current-version envelope with no content is malformed")
    func malformed() {
        let json = #"{"version":\#(CorePayload.version)}"#
        #expect(throws: WatchMessage.CodecError.malformed) {
            try WatchMessage(data: Data(json.utf8))
        }
    }
}
