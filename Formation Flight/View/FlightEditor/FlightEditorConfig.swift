//
//  FlightEditorConfig.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/24/23.
//

import Foundation

struct FlightEditorConfig {
    var flight = Flight.emptyFlight()
    var shouldSaveChanges = false
    var isPresented = false
    
    mutating func presentAddFlight() {
        flight = Flight.emptyFlight()
        shouldSaveChanges = false
        isPresented = true
    }
    
    mutating func presentEditFlight(_ flightToEdit: Flight) {
        flight = flightToEdit
        shouldSaveChanges = false
        isPresented = true
    }
    
    mutating func done() {
        shouldSaveChanges = true
        isPresented = false
    }
    
    mutating func cancel() {
        shouldSaveChanges = false
        isPresented = false
    }
}
