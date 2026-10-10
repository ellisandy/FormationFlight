import Foundation
import Testing
@testable import Formation_Flight
import FormationFlightCore

@Suite("Settings Tests")
struct SettingsTests {

    // MARK: - Helpers
    private func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }

    private func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    // MARK: - Codable round-trip
    @Test("Settings encodes and decodes symmetrically")
    func testCodableRoundTrip() throws {
        let original = Settings(
            speedUnit: .kts,
            distanceUnit: .nm,
            yellowTolerance: 3,
            redTolerance: 7,
            instrumentSettings: [
                InstrumentSetting(type: .currentGroundSpeed, isEnabled: true),
                InstrumentSetting(type: .bearing, isEnabled: false)
            ]
        )
        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(Settings.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Equatable semantics
    @Test("Settings equatable compares all fields including instrumentSettings")
    func testEquatable() throws {
        let a = Settings(
            speedUnit: .kts,
            distanceUnit: .nm,
            yellowTolerance: 1,
            redTolerance: 2,
            instrumentSettings: [InstrumentSetting(type: .track, isEnabled: true)]
        )
        var b = a
        #expect(a == b)
        b.redTolerance = 3
        #expect(a != b)
        b = a
        b.instrumentSettings[0].isEnabled.toggle()
        #expect(a != b)
    }

    // MARK: - Unit conversion helpers
    @Test("getUnitSpeed returns matching UnitSpeed")
    func testGetUnitSpeed() {
        #expect(Settings(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getUnitSpeed() == .knots)
        #expect(Settings(speedUnit: .kph, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getUnitSpeed() == .kilometersPerHour)
        #expect(Settings(speedUnit: .mph, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getUnitSpeed() == .milesPerHour)
    }

    @Test("getDistanceUnits returns matching UnitLength")
    func testGetDistanceUnits() {
        #expect(Settings(speedUnit: .kts, distanceUnit: .km, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getDistanceUnits() == .kilometers)
        #expect(Settings(speedUnit: .kts, distanceUnit: .mi, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getDistanceUnits() == .miles)
        #expect(Settings(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 0, redTolerance: 0, instrumentSettings: []).getDistanceUnits() == .nauticalMiles)
    }

    // MARK: - Defaults
    @Test("empty() provides expected defaults and instruments enabled")
    func testEmptyDefaults() {
        let s = Settings.empty()
        #expect(s.speedUnit == .kts)
        #expect(s.distanceUnit == .nm)
        // B-05: a fresh install must not treat every non-zero delta as red.
        // Default tolerances must be non-zero and ordered yellow <= red.
        #expect(s.yellowTolerance > 0)
        #expect(s.redTolerance > 0)
        #expect(s.yellowTolerance <= s.redTolerance)
        // Ensure we have at least the 5 default instruments and they are enabled as specified
        #expect(s.instrumentSettings.count == 5)
        #expect(s.instrumentSettings.allSatisfy { $0.isEnabled })
        // Sanity check types exist
        let expected: [InFlightInfo] = [.currentGroundSpeed, .requiredGroundSpeed, .distance, .bearing, .track]
        #expect(Set(s.instrumentSettings.map { $0.type }) == Set(expected))
    }

    // MARK: - Persistence: load/save with merge behavior
    @Test("save(to:) and load(from:) round-trip and merge saved instrument isEnabled over defaults")
    func testLoadSaveMerge() throws {
        let defaults = UserDefaults(suiteName: "SettingsTests.testLoadSaveMerge")!
        defaults.removePersistentDomain(forName: "SettingsTests.testLoadSaveMerge")

        // Step 1: start with an initial settings where one default instrument is disabled
        var initial = Settings.empty()
        // Disable bearing in saved settings
        if let idx = initial.instrumentSettings.firstIndex(where: { $0.type == .bearing }) {
            initial.instrumentSettings[idx].isEnabled = false
        }
        initial.yellowTolerance = 9
        initial.redTolerance = 11
        initial.speedUnit = .mph
        initial.distanceUnit = .mi

        // Save
        initial.save(to: defaults)

        // Step 2: Load back; expect merge preserves saved isEnabled values, retains new defaults if any
        let loaded = Settings.load(from: defaults)

        #expect(loaded.speedUnit == .mph)
        #expect(loaded.distanceUnit == .mi)
        #expect(loaded.yellowTolerance == 9)
        #expect(loaded.redTolerance == 11)

        // Verify merge logic: for each default type, if there was a saved entry, isEnabled should match saved
        let defaultsList = Settings.empty().instrumentSettings
        for def in defaultsList {
            let loadedMatch = loaded.instrumentSettings.first { $0.type == def.type }
            #expect(loadedMatch != nil)
        }
        // Specifically, bearing should be disabled due to saved state
        let bearingLoaded = loaded.instrumentSettings.first { $0.type == .bearing }
        #expect(bearingLoaded?.isEnabled == false)
    }

    // MARK: - Persistence: tolerance defaults vs explicit values
    @Test("load(from:) on a fresh UserDefaults returns the default tolerances, not 0")
    func testLoadFreshDefaultsUsesDefaultTolerances() throws {
        let suiteName = "SettingsTests.testLoadFreshDefaultsUsesDefaultTolerances"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // B-05: UserDefaults.integer(forKey:) returns 0 for a never-set key, which
        // made every non-zero delta "red" on a fresh install. Loading from an empty
        // store must yield the same tolerances as empty().
        let loaded = Settings.load(from: defaults)
        let expected = Settings.empty()

        #expect(loaded.yellowTolerance == expected.yellowTolerance)
        #expect(loaded.redTolerance == expected.redTolerance)
        #expect(loaded.yellowTolerance > 0)
        #expect(loaded.redTolerance > 0)
        #expect(loaded.yellowTolerance <= loaded.redTolerance)
    }

    @Test("load(from:) keeps an explicitly saved 0/0 tolerance pair")
    func testLoadExplicitZeroTolerancesArePreserved() throws {
        let suiteName = "SettingsTests.testLoadExplicitZeroTolerancesArePreserved"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // A user who deliberately saves 0/0 must get 0/0 back; the default
        // fallback must only apply when the keys were never written.
        var saved = Settings.empty()
        saved.yellowTolerance = 0
        saved.redTolerance = 0
        saved.save(to: defaults)

        let loaded = Settings.load(from: defaults)
        #expect(loaded.yellowTolerance == 0)
        #expect(loaded.redTolerance == 0)
    }

    // MARK: - Persistence: instrument ordering (B-12)
    //
    // `Settings.load(from:)` must rebuild the list in the SAVED order (the user reordered it),
    // then append any default type the saved list lacks, enabled, and drop anything it does
    // not recognise.

    @Test("load(from:) keeps the saved instrument order and appends missing defaults enabled")
    func testLoadPreservesSavedOrderAndAppendsMissingDefaults() throws {
        let suiteName = "SettingsTests.testLoadPreservesSavedOrderAndAppendsMissingDefaults"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var saved = Settings.empty()
        saved.instrumentSettings = [
            InstrumentSetting(type: .track, isEnabled: false),
            InstrumentSetting(type: .distance, isEnabled: true),
            InstrumentSetting(type: .currentGroundSpeed, isEnabled: false),
        ]
        saved.save(to: defaults)

        let loaded = Settings.load(from: defaults)

        #expect(loaded.instrumentSettings.map(\.type) == [.track, .distance, .currentGroundSpeed, .requiredGroundSpeed, .bearing])
        #expect(loaded.instrumentSettings.map(\.isEnabled) == [false, true, false, true, true])
    }

    @Test("load(from:) drops a saved type that is not a default instrument")
    func testLoadDropsNonInstrumentTypes() throws {
        let suiteName = "SettingsTests.testLoadDropsNonInstrumentTypes"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // "ToT" is a valid InFlightInfo case but not an instrument the settings list offers.
        let json = """
        [
          {"type": "ToT", "isEnabled": true},
          {"type": "Track", "isEnabled": false}
        ]
        """
        defaults.set(Data(json.utf8), forKey: "instrumentSettings")

        let loaded = Settings.load(from: defaults)
        #expect(!loaded.instrumentSettings.contains { $0.type == .tot })
        #expect(loaded.instrumentSettings.first?.type == .track)
        #expect(loaded.instrumentSettings.first?.isEnabled == false)
        #expect(loaded.instrumentSettings.count == 5)
    }

    @Test("load(from:) keeps the first of duplicate saved types")
    func testLoadDropsDuplicateSavedTypes() throws {
        let suiteName = "SettingsTests.testLoadDropsDuplicateSavedTypes"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let json = """
        [
          {"type": "Dist", "isEnabled": false},
          {"type": "Dist", "isEnabled": true}
        ]
        """
        defaults.set(Data(json.utf8), forKey: "instrumentSettings")

        let loaded = Settings.load(from: defaults)
        #expect(loaded.instrumentSettings.filter { $0.type == .distance }.count == 1)
        #expect(loaded.instrumentSettings.first?.type == .distance)
        #expect(loaded.instrumentSettings.first?.isEnabled == false)
        #expect(loaded.instrumentSettings.count == 5)
    }

    // MARK: - Persistence: corrupt instrumentSettings payloads
    //
    // A blob that is not JSON at all falls back to the defaults. A blob with one bad element
    // is decoded leniently so a single unknown type does not wipe the user's layout.

    @Test("load(from:) returns the default instrument list when the stored blob is not JSON")
    func testLoadCorruptInstrumentSettingsDataFallsBackToDefaults() throws {
        let suiteName = "SettingsTests.testLoadCorruptInstrumentSettingsDataFallsBackToDefaults"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("definitely not json".utf8), forKey: "instrumentSettings")

        let loaded = Settings.load(from: defaults)
        #expect(loaded.instrumentSettings == Settings.empty().instrumentSettings)
        #expect(loaded.instrumentSettings.allSatisfy { $0.isEnabled })
    }

    @Test("load(from:) drops a saved entry with an unknown type and keeps the valid entries")
    func testLoadUnknownInstrumentTypeIsDroppedAndValidEntriesKept() throws {
        let suiteName = "SettingsTests.testLoadUnknownInstrumentTypeIsDroppedAndValidEntriesKept"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Decision (B-12): decode leniently per element. Before, `InstrumentSetting.init(from:)`
        // throwing on the unknown `type` failed the whole array and this test pinned the
        // all-or-nothing fallback. One stale entry (for example from a build that had an
        // instrument this one does not) must not discard the user's whole layout, so now the
        // bad element is dropped and the valid "Cur GS": false entry survives in first place.
        let json = """
        [
          {"type": "Cur GS", "isEnabled": false},
          {"type": "Not An Instrument", "isEnabled": true}
        ]
        """
        defaults.set(Data(json.utf8), forKey: "instrumentSettings")

        let loaded = Settings.load(from: defaults)
        #expect(loaded.instrumentSettings.map(\.type) == [.currentGroundSpeed, .requiredGroundSpeed, .distance, .bearing, .track])
        #expect(loaded.instrumentSettings.map(\.isEnabled) == [false, true, true, true, true])
    }

    @Test("load(from:) drops a saved element that is not an object")
    func testLoadNonObjectElementIsDropped() throws {
        let suiteName = "SettingsTests.testLoadNonObjectElementIsDropped"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let json = """
        [
          42,
          {"type": "Final Bearing", "isEnabled": false}
        ]
        """
        defaults.set(Data(json.utf8), forKey: "instrumentSettings")

        let loaded = Settings.load(from: defaults)
        #expect(loaded.instrumentSettings.first?.type == .bearing)
        #expect(loaded.instrumentSettings.first?.isEnabled == false)
        #expect(loaded.instrumentSettings.count == 5)
    }

    // MARK: - Tolerance validation
    @Test("validated() raises red to yellow when yellow > red")
    func testValidatedFixesInvertedTolerances() {
        var s = Settings.empty()
        s.yellowTolerance = 40
        s.redTolerance = 15

        let v = s.validated()
        #expect(v.yellowTolerance == 40)
        #expect(v.redTolerance == 40)
        #expect(v.yellowTolerance <= v.redTolerance)
        // Non-tolerance fields are untouched
        #expect(v.speedUnit == s.speedUnit)
        #expect(v.distanceUnit == s.distanceUnit)
        #expect(v.instrumentSettings == s.instrumentSettings)
    }

    @Test("validated() clamps negative tolerances to 0")
    func testValidatedClampsNegatives() {
        var s = Settings.empty()
        s.yellowTolerance = -5
        s.redTolerance = -1

        let v = s.validated()
        #expect(v.yellowTolerance == 0)
        #expect(v.redTolerance == 0)
    }

    @Test("validated() leaves an already-valid pair unchanged")
    func testValidatedIsIdentityForValidPair() {
        var s = Settings.empty()
        s.yellowTolerance = 5
        s.redTolerance = 10
        #expect(s.validated() == s)
        #expect(Settings.empty().validated() == Settings.empty())
    }

    @Test("defaults() matches empty()")
    func testDefaultsMatchesEmpty() {
        #expect(Settings.defaults() == Settings.empty())
        #expect(Settings.defaults().yellowTolerance == Settings.defaultYellowTolerance)
        #expect(Settings.defaults().redTolerance == Settings.defaultRedTolerance)
    }

    @Test("load(from:) normalizes a persisted inverted tolerance pair")
    func testLoadNormalizesInvertedTolerances() throws {
        let suiteName = "SettingsTests.testLoadNormalizesInvertedTolerances"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Write a corrupted/legacy pair straight through the dumb writer.
        var saved = Settings.empty()
        saved.yellowTolerance = 50
        saved.redTolerance = 20
        saved.save(to: defaults)

        let loaded = Settings.load(from: defaults)
        #expect(loaded.yellowTolerance == 50)
        #expect(loaded.redTolerance == 50)
    }

    // MARK: - Decoding ignores unknown CodingKeys (minSpeed/maxSpeed/proximityToNextPoint)
    @Test("Decoding ignores removed keys and still succeeds")
    func testDecodingIgnoresRemovedKeys() throws {
        // Construct legacy-looking JSON with extra keys
        let json = """
        {
          "speedUnit": "kts",
          "distanceUnit": "nm",
          "yellowTolerance": 1,
          "redTolerance": 2,
          "instrumentSettings": [
            {"type": "Cur GS", "isEnabled": true},
            {"type": "Req GS", "isEnabled": true},
            {"type": "Dist", "isEnabled": true},
            {"type": "Final Bearing", "isEnabled": true},
            {"type": "Track", "isEnabled": true}
          ]
        }
        """.data(using: .utf8)!

        let decoded = try makeDecoder().decode(Settings.self, from: json)
        #expect(decoded.speedUnit == .kts)
        #expect(decoded.distanceUnit == .nm)
        #expect(decoded.yellowTolerance == 1)
        #expect(decoded.redTolerance == 2)
        #expect(decoded.instrumentSettings.count == 5)
    }

    // MARK: - Callouts (F-01)
    @Test("Callouts default to everything on, voice included, with a 10 kt threshold")
    func testCalloutDefaults() {
        let c = Settings.empty().callouts
        #expect(c.voiceEnabled && c.countdownEnabled && c.turnInEnabled && c.driftEnabled && c.speedAndGPSEnabled)
        #expect(c.speedThresholdKnots == 10)
    }

    @Test("Callout settings round-trip through UserDefaults")
    func testCalloutPersistence() throws {
        let suiteName = "SettingsTests.testCalloutPersistence"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var s = Settings.empty()
        s.callouts.voiceEnabled = false
        s.callouts.driftEnabled = false
        s.callouts.speedThresholdKnots = 22
        s.save(to: defaults)
        #expect(Settings.load(from: defaults).callouts == s.callouts)
    }

    @Test("Settings JSON from before callouts decodes with the default callouts")
    func testDecodingWithoutCallouts() throws {
        let json = """
        {"speedUnit": "kts", "distanceUnit": "nm", "yellowTolerance": 1, "redTolerance": 2, "instrumentSettings": []}
        """.data(using: .utf8)!
        #expect(try makeDecoder().decode(Settings.self, from: json).callouts == .defaults)
    }

    @Test("Callout settings decode leniently, keeping known keys and defaulting the rest")
    func testCalloutLenientDecoding() throws {
        let json = #"{"voiceEnabled": false, "speedThresholdKnots": "bad", "futureKey": 1}"#.data(using: .utf8)!
        let decoded = try makeDecoder().decode(CalloutSettings.self, from: json)
        #expect(decoded.voiceEnabled == false)
        #expect(decoded.countdownEnabled == true)
        #expect(decoded.speedThresholdKnots == CalloutSettings.defaultSpeedThresholdKnots)
    }

    @Test("validated() clamps the speed threshold to 5 – 30 kt")
    func testCalloutThresholdClamp() {
        var s = Settings.empty()
        s.callouts.speedThresholdKnots = 100
        #expect(s.validated().callouts.speedThresholdKnots == 30)
        s.callouts.speedThresholdKnots = 1
        #expect(s.validated().callouts.speedThresholdKnots == 5)
    }
}
