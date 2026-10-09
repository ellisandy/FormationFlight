//
//  Formation_Flight_WatchApp.swift
//  Formation Flight Watch Watch App
//
//  F-02: the Apple Watch companion. A read-only mirror of the iPhone's flight screen with
//  haptic cues; the phone is the GPS source and the source of truth.
//

import SwiftUI

@main
struct Formation_Flight_Watch_Watch_AppApp: App {
    @State private var model: WatchFlightModel
    /// Kept for the life of the app: it is the session's delegate.
    private let connection: PhoneConnection

    init() {
        let model = WatchFlightModel()
        _model = State(initialValue: model)
        // Activated at launch so a flight already under way (the application context) shows
        // straight away.
        connection = PhoneConnection { message in
            model.receive(message)
        }
        connection.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchFlightView(model: model)
        }
    }
}
