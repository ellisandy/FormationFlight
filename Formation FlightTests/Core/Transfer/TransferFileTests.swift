import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

@Suite
struct TransferFileTests {
    @Test
    func flightRoundTripCreatesIndependentFlight() throws {
        let original = Flight(
            missionName: "Backup Mission",
            missionType: .tot,
            missionDate: Date(timeIntervalSince1970: 1_700_000_000),
            target: Target(longitude: -122.4783, latitude: 37.8199)
        )

        let encoded = try TransferFileCodec.encoder.encode(FlightTransferPayload(flight: original))
        let decoded = try TransferFileCodec.decoder.decode(FlightTransferPayload.self, from: encoded)
        let imported = try decoded.makeFlight()

        #expect(imported.id != original.id)
        #expect(imported.missionName == original.missionName)
        #expect(imported.missionType == original.missionType)
        #expect(imported.missionDate == original.missionDate)
        #expect(imported.target?.latitude == original.target?.latitude)
        #expect(imported.target?.longitude == original.target?.longitude)
    }

    @Test
    func oldTOTRemainsImportableAsBackup() throws {
        let original = Flight(
            missionName: "Earlier Mission",
            missionType: .tot,
            missionDate: Date(timeIntervalSince1970: 1),
            target: Target(longitude: 0, latitude: 0)
        )

        let imported = try FlightTransferPayload(flight: original).makeFlight()

        #expect(imported.missionDate == original.missionDate)
    }

    @Test
    func totHackRoundTripKeepsPlannedTOTAndHack() throws {
        let original = Flight(
            missionName: "Mixed Mission",
            missionType: .totHack,
            missionDate: Date(timeIntervalSince1970: 1_700_000_000),
            target: Target(longitude: -122.4783, latitude: 37.8199),
            hackTime: 300
        )

        let encoded = try TransferFileCodec.encoder.encode(FlightTransferPayload(flight: original))
        let imported = try TransferFileCodec.decoder.decode(FlightTransferPayload.self, from: encoded).makeFlight()

        #expect(imported.missionType == .totHack)
        #expect(imported.missionDate == original.missionDate)
        #expect(imported.hackTime == 300)
    }

    @Test
    func totHackWithoutHackIsRejected() throws {
        let original = Flight(
            missionName: "Mixed Mission",
            missionType: .totHack,
            missionDate: Date(timeIntervalSince1970: 1_700_000_000),
            target: Target(longitude: 0, latitude: 0),
            hackTime: nil
        )

        #expect(throws: TransferFileError.self) {
            try FlightTransferPayload(flight: original).makeFlight()
        }
    }

    @Test
    func preferencesRoundTripReplacesWholeSnapshot() throws {
        let settings = Settings(
            speedUnit: .mph,
            distanceUnit: .mi,
            yellowTolerance: 12,
            redTolerance: 34,
            instrumentSettings: [
                InstrumentSetting(type: .distance, isEnabled: false),
                InstrumentSetting(type: .track, isEnabled: true)
            ],
            callouts: .defaults
        )

        let encoded = try TransferFileCodec.encoder.encode(PreferencesTransferPayload(settings: settings))
        let decoded = try TransferFileCodec.decoder.decode(PreferencesTransferPayload.self, from: encoded)

        #expect(try decoded.importedSettings() == settings)
    }

    @Test
    func sharedFilenameRemovesUnsafeCharacters() {
        #expect(TransferFileCodec.safeFilename("Lead/Two:Backup", fallback: "Flight") == "Lead-Two-Backup")
        #expect(TransferFileCodec.safeFilename("   ", fallback: "Flight") == "Flight")
    }
}
