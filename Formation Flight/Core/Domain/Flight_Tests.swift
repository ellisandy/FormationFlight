import Foundation
import Testing
@testable import Formation_Flight

@Suite
struct FlightTests {
  var sampleTarget: Target {

      Target(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, longitude: 0.0, latitude: 1.0)
  }

  var sampleDate: Date {
    Date(timeIntervalSince1970: 1_000_000) // deterministic date
  }

  var sampleHackTime: TimeInterval { // seconds
    2_000 // deterministic hack time
  }

  @Test
  func testValidFlight() throws {
    let flight = Flight(
      missionName: "Valid Mission",
      missionType: .hackTime,
      missionDate: nil,
      target: sampleTarget,
      hackTime: sampleHackTime
    )
    let validation = flight.validFlight()
    #expect(validation.valid)
    #expect(validation.message == nil)
  }

  @Test
  func testEmptyMissionName() throws {
    // Use a configuration that doesn't trip other validations
    let flight = Flight(
      missionName: "",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("name"))
  }

  @Test
  func testHackTimeNil() throws {
    let flight = Flight(
      missionName: "HackTime Mission",
      missionType: .hackTime,
      missionDate: nil,
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("hack time"))
  }

  @Test
  func testTotNilDate() throws {
    let flight = Flight(
      missionName: "TOT Mission",
      missionType: .tot,
      missionDate: nil,
      target: sampleTarget,
      hackTime: nil
    )
    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("date"))
  }

  @Test
  func testNilTarget() throws {
    let flight = Flight(
      missionName: "No Target Mission",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    // Set target to nil after initialization to simulate missing target
    flight.target = nil

    let validation = flight.validFlight()
    #expect(!validation.valid)
    #expect(validation.message != nil)
    #expect(validation.message!.localizedCaseInsensitiveContains("target"))
  }

  @Test
  func testEqualityAndHashing() throws {
    let id = UUID()
    let flight1 = Flight(
      missionName: "Mission 1",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    flight1.id = id

    let flight2 = Flight(
      missionName: "Mission 1",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )
    flight2.id = id

    let flight3 = Flight(
      missionName: "Mission 3",
      missionType: .tot,
      missionDate: sampleDate,
      target: sampleTarget,
      hackTime: nil
    )

    // Same id, equal
    #expect(flight1 == flight2)
    // Different id, not equal
    #expect(flight1 != flight3)

    // Set uniqueness by id
    var set = Set<Flight>()
    set.insert(flight1)
    set.insert(flight2)
    set.insert(flight3)
    #expect(set.count == 2)
    #expect(set.contains(flight1))
    #expect(set.contains(flight3))
  }
}

