//
//  Date+Components.swift
//  Formation Flight
//
//  Created by AI Assistant on 11/16/25.
//

import Foundation

public extension Date {
    /// Returns a new date by setting provided hour/minute/second on the same calendar day in the current calendar/timezone.
    func setting(hour: Int? = nil, minute: Int? = nil, second: Int? = nil, calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: self)
        var newComps = comps
        if let h = hour { newComps.hour = h }
        if let m = minute { newComps.minute = m }
        if let s = second { newComps.second = s }
        return calendar.date(from: newComps) ?? self
    }
    
    /// Extracts hour/minute/second components in current calendar/timezone.
    func hms(calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()) -> (hour: Int, minute: Int, second: Int) {
        let comps = calendar.dateComponents([.hour, .minute, .second], from: self)
        return (
            comps.hour ?? 0,
            comps.minute ?? 0,
            comps.second ?? 0
        )
    }
}
