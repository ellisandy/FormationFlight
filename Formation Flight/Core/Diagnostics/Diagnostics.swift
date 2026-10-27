import CoreLocation
import CoreTransferable
import Foundation
import Observation
import UniformTypeIdentifiers
import FormationFlightCore

enum DiagnosticPreferences {
    private static let enabledKey = "diagnosticsModeEnabled"

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}

struct DiagnosticFlightSnapshot: Codable, Equatable {
    let missionName: String
    let missionType: MissionType
    let missionDate: Date?
    let hackTime: TimeInterval?
    let targetLatitude: Double
    let targetLongitude: Double
}

struct DiagnosticEvent: Codable, Equatable {
    let sequence: Int
    let timestamp: Date
    let kind: String

    var latitude: Double?
    var longitude: Double?
    var altitudeMeters: Double?
    var horizontalAccuracyMeters: Double?
    var verticalAccuracyMeters: Double?
    var speedMetersPerSecond: Double?
    var speedAccuracyMetersPerSecond: Double?
    var courseDegreesTrue: Double?
    var courseAccuracyDegrees: Double?
    var fixTimestamp: Date?
    var fixAgeSeconds: TimeInterval?

    var tot: Date?
    var distanceMeters: Double?
    var bearingDegreesTrue: Double?
    var trackDegreesTrue: Double?
    var eteSeconds: TimeInterval?
    var eta: Date?
    var deltaSeconds: TimeInterval?
    var requiredGroundSpeedMetersPerSecond: Double?
    var status: String?
    var isFixStale: Bool?
    var turnDirection: String?
    var turnInDirection: String?
    var turnDurationSeconds: TimeInterval?
    var detail: String?

    init(sequence: Int, timestamp: Date, kind: String) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.kind = kind
    }
}

struct DiagnosticReport: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sessionID: UUID
    let startedAt: Date
    var endedAt: Date?
    var durationSeconds: TimeInterval?
    let appVersion: String
    let appBuild: String
    let operatingSystem: String
    let deviceModel: String
    let flight: DiagnosticFlightSnapshot
    let settings: Settings
    var events: [DiagnosticEvent]
}

struct DiagnosticSessionSummary: Identifiable, Equatable {
    let id: UUID
    let missionName: String
    let startedAt: Date
    let durationSeconds: TimeInterval
    let fileURL: URL
    let fileSize: Int64
}

struct DiagnosticShareFile: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            SentTransferredFile(item.fileURL)
        }
    }
}

@MainActor
@Observable
final class DiagnosticSessionStore {
    static let shared = DiagnosticSessionStore()

    static let retentionInterval: TimeInterval = 14 * 24 * 60 * 60

    private(set) var sessions: [DiagnosticSessionSummary] = []
    private let fileManager: FileManager
    private let directoryURL: URL
    private let now: () -> Date

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.now = now
        self.directoryURL = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "Diagnostics", directoryHint: .isDirectory)
        refresh()
    }

    func makeRecorder(
        missionName: String,
        missionType: MissionType,
        missionDate: Date?,
        hackTime: TimeInterval?,
        target: CLLocationCoordinate2D,
        settings: Settings
    ) -> DiagnosticSessionRecorder? {
        guard DiagnosticPreferences.isEnabled() else { return nil }
        cleanupExpired()
        return DiagnosticSessionRecorder(
            store: self,
            missionName: missionName,
            missionType: missionType,
            missionDate: missionDate,
            hackTime: hackTime,
            target: target,
            settings: settings,
            now: now
        )
    }

    func refresh() {
        ensureDirectory()
        cleanupExpiredFiles()
        sessions = loadSessions()
    }

    func deleteAll() throws {
        ensureDirectory()
        for url in try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) where url.pathExtension.lowercased() == "json" {
            try fileManager.removeItem(at: url)
        }
        sessions = []
    }

    fileprivate func save(_ report: DiagnosticReport, refreshSessions: Bool = true) throws -> URL {
        ensureDirectory()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: report.startedAt)
            .replacingOccurrences(of: ":", with: "-")
        let mission = TransferFileCodec.safeFilename(report.flight.missionName, fallback: "Flight")
        let filename = "\(timestamp)_\(mission)_\(report.sessionID.uuidString.prefix(8)).json"
        let url = directoryURL.appending(path: filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(report).write(to: url, options: .atomic)
        if refreshSessions {
            refresh()
        }
        return url
    }

    func cleanupExpired() {
        cleanupExpiredFiles()
        sessions = loadSessions()
    }

    private func ensureDirectory() {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            AppLogger.data.error("Could not create diagnostics directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func cleanupExpiredFiles() {
        ensureDirectory()
        let cutoff = now().addingTimeInterval(-Self.retentionInterval)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        for url in urls where url.pathExtension.lowercased() == "json" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values?.contentModificationDate, modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func loadSessions() -> [DiagnosticSessionSummary] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "json",
                  let data = try? Data(contentsOf: url),
                  let report = try? decoder.decode(DiagnosticReport.self, from: data) else {
                return nil
            }
            let effectiveEnd = report.endedAt ?? report.events.last?.timestamp ?? report.startedAt
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return DiagnosticSessionSummary(
                id: report.sessionID,
                missionName: report.flight.missionName,
                startedAt: report.startedAt,
                durationSeconds: report.durationSeconds ?? effectiveEnd.timeIntervalSince(report.startedAt),
                fileURL: url,
                fileSize: size
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
    }
}

@MainActor
final class DiagnosticSessionRecorder {
    private unowned let store: DiagnosticSessionStore
    private let now: () -> Date
    private var report: DiagnosticReport
    private var hasFinished = false

    init(
        store: DiagnosticSessionStore,
        missionName: String,
        missionType: MissionType,
        missionDate: Date?,
        hackTime: TimeInterval?,
        target: CLLocationCoordinate2D,
        settings: Settings,
        now: @escaping () -> Date
    ) {
        self.store = store
        self.now = now
        let startedAt = now()
        report = DiagnosticReport(
            schemaVersion: DiagnosticReport.currentSchemaVersion,
            sessionID: UUID(),
            startedAt: startedAt,
            endedAt: nil,
            durationSeconds: nil,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: Self.deviceModel,
            flight: DiagnosticFlightSnapshot(
                missionName: missionName,
                missionType: missionType,
                missionDate: missionDate,
                hackTime: hackTime,
                targetLatitude: target.latitude,
                targetLongitude: target.longitude
            ),
            settings: settings,
            events: []
        )
        record(kind: "sessionStarted")
        checkpoint()
    }

    func recordLocation(_ location: CLLocation, receivedAt: Date) {
        var event = nextEvent(kind: "location", at: receivedAt)
        event.latitude = location.coordinate.latitude
        event.longitude = location.coordinate.longitude
        event.altitudeMeters = location.altitude
        event.horizontalAccuracyMeters = location.horizontalAccuracy
        event.verticalAccuracyMeters = location.verticalAccuracy
        event.speedMetersPerSecond = location.speed
        event.speedAccuracyMetersPerSecond = location.speedAccuracy
        event.courseDegreesTrue = location.course
        event.courseAccuracyDegrees = location.courseAccuracy
        event.fixTimestamp = location.timestamp
        event.fixAgeSeconds = receivedAt.timeIntervalSince(location.timestamp)
        report.events.append(event)
        checkpointIfNeeded()
    }

    func recordCalculation(
        at timestamp: Date,
        tot: Date?,
        distanceMeters: Double?,
        bearingDegrees: Double?,
        trackDegrees: Double?,
        ete: TimeInterval?,
        eta: Date?,
        delta: TimeInterval?,
        requiredGroundSpeed: Double?,
        status: String,
        isFixStale: Bool,
        turnDirection: String?,
        turnInDirection: String?,
        turnDuration: TimeInterval?
    ) {
        var event = nextEvent(kind: "calculation", at: timestamp)
        event.tot = tot
        event.distanceMeters = distanceMeters
        event.bearingDegreesTrue = bearingDegrees
        event.trackDegreesTrue = trackDegrees
        event.eteSeconds = ete
        event.eta = eta
        event.deltaSeconds = delta
        event.requiredGroundSpeedMetersPerSecond = requiredGroundSpeed
        event.status = status
        event.isFixStale = isFixStale
        event.turnDirection = turnDirection
        event.turnInDirection = turnInDirection
        event.turnDurationSeconds = turnDuration
        report.events.append(event)
        checkpointIfNeeded()
    }

    func record(kind: String, detail: String? = nil) {
        var event = nextEvent(kind: kind, at: now())
        event.detail = detail
        report.events.append(event)
        checkpointIfNeeded()
    }

    func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        record(kind: "sessionEnded")
        let endedAt = now()
        report.endedAt = endedAt
        report.durationSeconds = max(0, endedAt.timeIntervalSince(report.startedAt))
        do {
            _ = try store.save(report)
        } catch {
            AppLogger.data.error("Could not save diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkpointIfNeeded() {
        if report.events.count.isMultiple(of: 30) {
            checkpoint()
        }
    }

    private func checkpoint() {
        do {
            _ = try store.save(report, refreshSessions: false)
        } catch {
            AppLogger.data.error("Could not checkpoint diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func nextEvent(kind: String, at timestamp: Date) -> DiagnosticEvent {
        DiagnosticEvent(sequence: report.events.count, timestamp: timestamp, kind: kind)
    }

    private static var deviceModel: String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        #else
        return "unknown"
        #endif
    }
}
