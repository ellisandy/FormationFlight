import Foundation

public extension Date {
    /// Returns the value of a specific calendar component from this date using the provided calendar (default .current)
    func component(_ component: Calendar.Component, calendar: Calendar = .current) -> Int {
        calendar.component(component, from: self)
    }
    
    /// Returns a new date by updating a single calendar component to the provided value (optionally clamped to a range).
    func updating(_ component: Calendar.Component, to value: Int, calendar: Calendar = .current, clampedTo range: ClosedRange<Int>? = nil) -> Date {
        let newValue = range.map { max($0.lowerBound, min($0.upperBound, value)) } ?? value
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        switch component {
        case .hour: comps.hour = newValue
        case .minute: comps.minute = newValue
        case .second: comps.second = newValue
        default: break
        }
        return calendar.date(from: comps) ?? self
    }
    
    // Convenience accessors
    var hour: Int { component(.hour) }
    var minute: Int { component(.minute) }
    var second: Int { component(.second) }
    
    func updatingHour(to value: Int, calendar: Calendar = .current) -> Date {
        updating(.hour, to: value, calendar: calendar, clampedTo: 0...23)
    }
    
    func updatingMinute(to value: Int, calendar: Calendar = .current) -> Date {
        updating(.minute, to: value, calendar: calendar, clampedTo: 0...59)
    }
    
    func updatingSecond(to value: Int, calendar: Calendar = .current) -> Date {
        updating(.second, to: value, calendar: calendar, clampedTo: 0...59)
    }
}
