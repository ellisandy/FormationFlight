import Foundation
import SwiftUI
import Testing
@testable import Formation_Flight

@Suite("Date+TimeComponents Tests")
struct DateTimeComponentsTests {
  // Fixed calendar and timezone for deterministic tests
  let calendar = Calendar(identifier: .gregorian)

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
    return calendar.date(from: components)!
  }

  @Test("component(_:calendar:) returns correct hour/minute/second for known date")
  func testComponentReturnsCorrectValues() {
    let date = makeDate(year: 2023, month: 7, day: 15, hour: 14, minute: 30, second: 45)
    #expect(date.component(.hour, calendar: calendar) == 14)
    #expect(date.component(.minute, calendar: calendar) == 30)
    #expect(date.component(.second, calendar: calendar) == 45)
  }

  @Test("convenience accessors hour/minute/second return expected values")
  func testConvenienceAccessors() {
    let date = makeDate(year: 2021, month: 12, day: 31, hour: 23, minute: 59, second: 58)
    #expect(date.hour == 23)
    #expect(date.minute == 59)
    #expect(date.second == 58)
  }

  @Test("updating(_:to:calendar:clampedTo:) sets hour/minute/second correctly without clamping when in range")
  func testUpdatingWithoutClamping() {
    let originalDate = makeDate(year: 2022, month: 1, day: 1, hour: 10, minute: 15, second: 20)

    let updatedHour = originalDate.updating(.hour, to: 5, calendar: calendar, clampedTo: nil)
    #expect(updatedHour.hour == 5)
    #expect(updatedHour.minute == 15)
    #expect(updatedHour.second == 20)

    let updatedMinute = originalDate.updating(.minute, to: 45, calendar: calendar, clampedTo: nil)
    #expect(updatedMinute.hour == 10)
    #expect(updatedMinute.minute == 45)
    #expect(updatedMinute.second == 20)

    let updatedSecond = originalDate.updating(.second, to: 30, calendar: calendar, clampedTo: nil)
    #expect(updatedSecond.hour == 10)
    #expect(updatedSecond.minute == 15)
    #expect(updatedSecond.second == 30)
  }

  @Test("updating with out-of-range values clamps hour/minute/second correctly")
  func testUpdatingClampingBehavior() {
    let originalDate = makeDate(year: 2022, month: 6, day: 15, hour: 12, minute: 30, second: 30)

    // Hours: clamp -5 to 0, 26 to 23
    let clampHourLow = originalDate.updating(.hour, to: -5, calendar: calendar, clampedTo: 0...23)
    #expect(clampHourLow.hour == 0)

    let clampHourHigh = originalDate.updating(.hour, to: 26, calendar: calendar, clampedTo: 0...23)
    #expect(clampHourHigh.hour == 23)

    // Minutes: clamp -1 to 0, 75 to 59
    let clampMinuteLow = originalDate.updating(.minute, to: -1, calendar: calendar, clampedTo: 0...59)
    #expect(clampMinuteLow.minute == 0)

    let clampMinuteHigh = originalDate.updating(.minute, to: 75, calendar: calendar, clampedTo: 0...59)
    #expect(clampMinuteHigh.minute == 59)

    // Seconds: clamp -10 to 0, 90 to 59
    let clampSecondLow = originalDate.updating(.second, to: -10, calendar: calendar, clampedTo: 0...59)
    #expect(clampSecondLow.second == 0)

    let clampSecondHigh = originalDate.updating(.second, to: 90, calendar: calendar, clampedTo: 0...59)
    #expect(clampSecondHigh.second == 59)
  }

  @Test("updating preserves other date components and does not roll over")
  func testUpdatingPreservesDateComponents() {
    let originalDate = makeDate(year: 2019, month: 11, day: 20, hour: 8, minute: 25, second: 40)

    let updatedHour = originalDate.updating(.hour, to: 5, calendar: calendar, clampedTo: nil)
    #expect(updatedHour.hour == 5)
    #expect(updatedHour.minute == 25)
    #expect(updatedHour.second == 40)
    #expect(updatedHour.component(.year, calendar: calendar) == 2019)
    #expect(updatedHour.component(.month, calendar: calendar) == 11)
    #expect(updatedHour.component(.day, calendar: calendar) == 20)

    let updatedMinute = originalDate.updating(.minute, to: 50, calendar: calendar, clampedTo: nil)
    #expect(updatedMinute.hour == 8)
    #expect(updatedMinute.minute == 50)
    #expect(updatedMinute.second == 40)
    #expect(updatedMinute.component(.year, calendar: calendar) == 2019)
    #expect(updatedMinute.component(.month, calendar: calendar) == 11)
    #expect(updatedMinute.component(.day, calendar: calendar) == 20)

    let updatedSecond = originalDate.updating(.second, to: 10, calendar: calendar, clampedTo: nil)
    #expect(updatedSecond.hour == 8)
    #expect(updatedSecond.minute == 25)
    #expect(updatedSecond.second == 10)
    #expect(updatedSecond.component(.year, calendar: calendar) == 2019)
    #expect(updatedSecond.component(.month, calendar: calendar) == 11)
    #expect(updatedSecond.component(.day, calendar: calendar) == 20)
  }
}

// MARK: - TOT editing: picker wheel ranges and Binding<Date> component glue

/// Covers BACKLOG B-04: the TOT picker wheels must offer exactly the values the `Date`
/// model can hold (hour 0...23, minute/second 0...59), and every TOT editor must go
/// through the same clamped setters so an out-of-range hour never rolls the date.
@Suite("TOT time component editing")
@MainActor
struct TOTTimeComponentEditingTests {
    /// Mutable backing store for a `Binding<Date>` under test.
    @MainActor
    final class DateBox {
        var date: Date
        init(_ date: Date) { self.date = date }
    }

    // The production helpers default to `Calendar.current`, so assertions use it too.
    let calendar = Calendar.current

    /// A mid-month date well away from any DST transition.
    func makeDate(hour: Int, minute: Int = 20, second: Int = 30) throws -> Date {
        try #require(calendar.date(from:
            DateComponents(year: 2025, month: 6, day: 15, hour: hour, minute: minute, second: second)))
    }

    func makeBinding(_ box: DateBox) -> Binding<Date> {
        Binding(get: { box.date }, set: { box.date = $0 })
    }

    func day(of date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    // MARK: Picker wheel ranges

    @Test("hour wheel offers 00 through 23, matching Date.hour")
    func pickerHourRangeCoversMidnightThroughTwentyThree() {
        #expect(TOTTimePickerView.hourRange == 0..<24)
        #expect(TOTTimePickerView.hourRange.contains(0))
        #expect(!TOTTimePickerView.hourRange.contains(24))
    }

    @Test("every hour the model can produce is selectable on the hour wheel")
    func pickerHourRangeContainsEveryModelHour() throws {
        let base = try makeDate(hour: 12)
        for hour in 0...23 {
            let modelHour = base.updatingHour(to: hour).hour
            #expect(TOTTimePickerView.hourRange.contains(modelHour),
                    "model hour \(modelHour) is not selectable on the hour wheel")
        }
    }

    @Test("minute and second wheels offer 00 through 59")
    func pickerMinuteAndSecondRangesMatchDateModel() {
        #expect(TOTTimePickerView.minuteRange == 0..<60)
        #expect(TOTTimePickerView.secondRange == 0..<60)
    }

    // MARK: Date.updatingHour at the boundaries

    @Test("updatingHour accepts 0 and 23 and clamps 24 without rolling the day")
    func updatingHourBoundariesDoNotRollDay() throws {
        let base = try makeDate(hour: 12)

        let midnight = base.updatingHour(to: 0)
        #expect(midnight.hour == 0)
        #expect(day(of: midnight) == 15)

        let lastHour = base.updatingHour(to: 23)
        #expect(lastHour.hour == 23)
        #expect(day(of: lastHour) == 15)

        let overflow = base.updatingHour(to: 24)
        #expect(overflow.hour == 23)
        #expect(day(of: overflow) == 15)
    }

    // MARK: Binding<Date> component glue (used by the in-flight TOT editor)

    @Test("Binding<Date>.hourComponent reads the hour and clamps writes to 0...23")
    func bindingHourComponentClampsAndNeverRollsDay() throws {
        let box = DateBox(try makeDate(hour: 12))
        let hour = makeBinding(box).hourComponent

        #expect(hour.wrappedValue == 12)

        hour.wrappedValue = 24
        #expect(box.date.hour == 23)
        #expect(day(of: box.date) == 15)
        #expect(hour.wrappedValue == 23)

        hour.wrappedValue = 0
        #expect(box.date.hour == 0)
        #expect(day(of: box.date) == 15)

        hour.wrappedValue = -1
        #expect(box.date.hour == 0)
        #expect(day(of: box.date) == 15)

        // Other components are preserved.
        #expect(box.date.minute == 20)
        #expect(box.date.second == 30)
    }

    @Test("Binding<Date>.minuteComponent and .secondComponent clamp writes to 0...59")
    func bindingMinuteAndSecondComponentsClamp() throws {
        let box = DateBox(try makeDate(hour: 12))
        let binding = makeBinding(box)

        binding.minuteComponent.wrappedValue = 60
        #expect(box.date.minute == 59)
        #expect(box.date.hour == 12)

        binding.minuteComponent.wrappedValue = -1
        #expect(box.date.minute == 0)

        binding.secondComponent.wrappedValue = 60
        #expect(box.date.second == 59)
        #expect(box.date.minute == 0)

        binding.secondComponent.wrappedValue = -1
        #expect(box.date.second == 0)

        #expect(day(of: box.date) == 15)
    }
}
