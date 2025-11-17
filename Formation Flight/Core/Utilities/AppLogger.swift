//
//  AppLogger.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
//

import Foundation
import os

enum AppLogger {
    // Centralized subsystem; falls back to a fixed string if bundle id is missing
    private static let subsystem = Bundle.main.bundleIdentifier ?? "FormationFlight"
    
    // UI and View-related logs
    static let ui = Logger(subsystem: subsystem, category: "UI")
    
    // View model / business logic
    static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")
    
    // Data persistence / SwiftData
    static let data = Logger(subsystem: subsystem, category: "Data")
    
    // Location / sensors
    static let location = Logger(subsystem: subsystem, category: "Location")
    
    // Flight domain-specific logs
    static let flight = Logger(subsystem: subsystem, category: "Flight")
    
    // Settings/configuration
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}

