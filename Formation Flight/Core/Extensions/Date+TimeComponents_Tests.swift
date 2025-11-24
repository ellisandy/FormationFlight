import Foundation
import Testing

@Suite("Date+TimeComponents Tests")
struct DateTimeComponentsTests {
  // Fixed calendar and timezone for deterministic tests
  let calendar = Calendar(identifier: .gregorian)
  let timeZone = TimeZone(secondsFromGMT: 0)!

  // Helper to create date from components in GMT calendar/timezone
  func makeDate(
    year: Int, month: Int, day: Int,
    hour: Int = 0, minute: Int = 0, second: Int = 0
  ) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    components.timeZone = timeZone
    return calendar.date(from: components)!
  }

  @Test("component(_:calendar:) returns correct hour/minute/second for known date")
  func testComponentReturnsCorrectValues() {
    let date = makeDate(year: 2023, month: 7, day: 15, hour: 14, minute: 30, second: 45)
    #expect(date.component(.hour, calendar: calendar)) == 14
    #expect(date.component(.minute, calendar: calendar)) == 30
    #expect(date.component(.second, calendar: calendar)) == 45
  }

  @Test("convenience accessors hour/minute/second return expected values")
  func testConvenienceAccessors() {
    let date = makeDate(year: 2021, month: 12, day: 31, hour: 23, minute: 59, second: 58)
    #expect(date.hour(calendar: calendar)) == 23
    #expect(date.minute(calendar: calendar)) == 59
    #expect(date.second(calendar: calendar)) == 58
  }

  @Test("updating(_:to:calendar:clampedTo:) sets hour/minute/second correctly without clamping when in range")
  func testUpdatingWithoutClamping() {
    let originalDate = makeDate(year: 2022, month: 1, day: 1, hour: 10, minute: 15, second: 20)

    let updatedHour = originalDate.updating(.hour, to: 5, calendar: calendar, clampedTo: true)
    #expect(updatedHour.hour(calendar: calendar)) == 5
    #expect(updatedHour.minute(calendar: calendar)) == 15
    #expect(updatedHour.second(calendar: calendar)) == 20

    let updatedMinute = originalDate.updating(.minute, to: 45, calendar: calendar, clampedTo: true)
    #expect(updatedMinute.hour(calendar: calendar)) == 10
    #expect(updatedMinute.minute(calendar: calendar)) == 45
    #expect(updatedMinute.second(calendar: calendar)) == 20

    let updatedSecond = originalDate.updating(.second, to: 30, calendar: calendar, clampedTo: true)
    #expect(updatedSecond.hour(calendar: calendar)) == 10
    #expect(updatedSecond.minute(calendar: calendar)) == 15
    #expect(updatedSecond.second(calendar: calendar)) == 30
  }

  @Test("updating with out-of-range values clamps hour/minute/second correctly")
  func testUpdatingClampingBehavior() {
    let originalDate = makeDate(year: 2022, month: 6, day: 15, hour: 12, minute: 30, second: 30)

    // Hours: clamp -5 to 0, 26 to 23
    let clampHourLow = originalDate.updating(.hour, to: -5, calendar: calendar, clampedTo: true)
    #expect(clampHourLow.hour(calendar: calendar)) == 0

    let clampHourHigh = originalDate.updating(.hour, to: 26, calendar: calendar, clampedTo: true)
    #expect(clampHourHigh.hour(calendar: calendar)) == 23

    // Minutes: clamp -1 to 0, 75 to 59
    let clampMinuteLow = originalDate.updating(.minute, to: -1, calendar: calendar, clampedTo: true)
    #expect(clampMinuteLow.minute(calendar: calendar)) == 0

    let clampMinuteHigh = originalDate.updating(.minute, to: 75, calendar: calendar, clampedTo: true)
    #expect(clampMinuteHigh.minute(calendar: calendar)) == 59

    // Seconds: clamp -10 to 0, 90 to 59
    let clampSecondLow = originalDate.updating(.second, to: -10, calendar: calendar, clampedTo: true)
    #expect(clampSecondLow.second(calendar: calendar)) == 0

    let clampSecondHigh = originalDate.updating(.second, to: 90, calendar: calendar, clampedTo: true)
    #expect(clampSecondHigh.second(calendar: calendar)) == 59
  }

  @Test("updating preserves other date components and does not roll over")
  func testUpdatingPreservesDateComponents() {
    let originalDate = makeDate(year: 2019, month: 11, day: 20, hour: 8, minute: 25, second: 40)

    let updatedHour = originalDate.updating(.hour, to: 5, calendar: calendar, clampedTo: true)
    #expect(updatedHour.hour(calendar: calendar)) == 5
    #expect(updatedHour.minute(calendar: calendar)) == 25
    #expect(updatedHour.second(calendar: calendar)) == 40
    #expect(updatedHour.component(.year, calendar: calendar)) == 2019
    #expect(updatedHour.component(.month, calendar: calendar)) == 11
    #expect(updatedHour.component(.day, calendar: calendar)) == 20

    let updatedMinute = originalDate.updating(.minute, to: 50, calendar: calendar, clampedTo: true)
    #expect(updatedMinute.hour(calendar: calendar)) == 8
    #expect(updatedMinute.minute(calendar: calendar)) == 50
    #expect(updatedMinute.second(calendar: calendar)) == 40
    #expect(updatedMinute.component(.year, calendar: calendar)) == 2019
    #expect(updatedMinute.component(.month, calendar: calendar)) == 11
    #expect(updatedMinute.component(.day, calendar: calendar)) == 20

    let updatedSecond = originalDate.updating(.second, to: 10, calendar: calendar, clampedTo: true)
    #expect(updatedSecond.hour(calendar: calendar)) == 8
    #expect(updatedSecond.minute(calendar: calendar)) == 25
    #expect(updatedSecond.second(calendar: calendar)) == 10
    #expect(updatedSecond.component(.year, calendar: calendar)) == 2019
    #expect(updatedSecond.component(.month, calendar: calendar)) == 11
    #expect(updatedSecond.component(.day, calendar: calendar)) == 20
  }
}
