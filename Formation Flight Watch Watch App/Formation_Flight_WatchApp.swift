//
//  Formation_Flight_WatchApp.swift
//  Formation Flight Watch Watch App
//
//  F-02: the Apple Watch companion. A read-only mirror of the iPhone's flight screen with
//  haptic cues; the phone is the GPS source and the source of truth.
//

import SwiftUI

#if canImport(FormationFlightCore)
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
#else
// The watch app's sources are all written against FormationFlightCore, and are compiled out
// until the package product is linked: target "Formation Flight Watch Watch App" > General >
// Frameworks, Libraries, and Embedded Content > + > FormationFlightCore. Until then this
// placeholder keeps the iPhone app (which embeds the watch app) building.
#warning("F-02: link FormationFlightCore to the Formation Flight Watch Watch App target")

@main
struct Formation_Flight_Watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            Text(verbatim: "FormationFlightCore not linked")
        }
    }
}
#endif
