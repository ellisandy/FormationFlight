import CoreLocation
import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

@Suite(.serialized)
@MainActor
struct DiagnosticsTests {
    @Test
    func recorderWritesReadableJSONWithLocationAndCalculation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let store = DiagnosticSessionStore(directoryURL: directory, now: { clock })
        let recorder = DiagnosticSessionRecorder(
            store: store,
            missionName: "Diagnostic Mission",
            missionType: .tot,
            missionDate: clock.addingTimeInterval(600),
            hackTime: nil,
            target: CLLocationCoordinate2D(latitude: 34, longitude: -118),
            settings: .defaults(),
            now: { clock }
        )

        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 33.9, longitude: -118.1),
            altitude: 1_000,
            horizontalAccuracy: 4,
            verticalAccuracy: 7,
            course: 90,
            speed: 70,
            timestamp: clock
        )
        recorder.recordLocation(fix, receivedAt: clock)
        recorder.recordCalculation(
            at: clock,
            tot: clock.addingTimeInterval(600),
            distanceMeters: 10_000,
            bearingDegrees: 45,
            trackDegrees: 90,
            ete: 140,
            eta: clock.addingTimeInterval(140),
            delta: -460,
            requiredGroundSpeed: 20,
            status: "good",
            isFixStale: false,
            turnDirection: nil,
            turnInDirection: "right",
            turnDuration: 15
        )
        clock = clock.addingTimeInterval(120)
        recorder.finish()

        store.refresh()
        let session = try #require(store.sessions.first)
        let data = try Data(contentsOf: session.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(DiagnosticReport.self, from: data)

        #expect(report.flight.missionName == "Diagnostic Mission")
        #expect(report.durationSeconds == 120)
        #expect(report.events.contains { $0.kind == "location" && $0.latitude == 33.9 })
        #expect(report.events.contains { $0.kind == "calculation" && $0.deltaSeconds == -460 })
        #expect(report.events.last?.kind == "sessionEnded")
    }

    @Test
    func cleanupDeletesOnlyReportsOlderThanFourteenDays() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let expired = directory.appending(path: "expired.json")
        let recent = directory.appending(path: "recent.json")
        try Data("{}".utf8).write(to: expired)
        try Data("{}".utf8).write(to: recent)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-DiagnosticSessionStore.retentionInterval - 1)],
            ofItemAtPath: expired.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-DiagnosticSessionStore.retentionInterval + 1)],
            ofItemAtPath: recent.path
        )

        let store = DiagnosticSessionStore(directoryURL: directory, now: { now })
        store.cleanupExpired()

        #expect(!FileManager.default.fileExists(atPath: expired.path))
        #expect(FileManager.default.fileExists(atPath: recent.path))
    }

    @Test
    func diagnosticsPreferencePersistsUntilManuallyChanged() {
        let suiteName = "DiagnosticsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(!DiagnosticPreferences.isEnabled(in: defaults))
        DiagnosticPreferences.setEnabled(true, in: defaults)
        #expect(DiagnosticPreferences.isEnabled(in: defaults))
        DiagnosticPreferences.setEnabled(false, in: defaults)
        #expect(!DiagnosticPreferences.isEnabled(in: defaults))
    }
}
