//
//  Date+Extensions.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/31/23.
//

import Foundation

extension Date {
    func secondsUntil(time: Date) -> Double {
        return time.timeIntervalSince(self)
    }
}
