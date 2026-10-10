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
    /// Kept for the life of the app: it is the session's delegate. Nil under a UI-test scenario.
    private let connection: PhoneConnection?
    #if DEBUG
    /// UI tests (`-uiTestScenario <name>`): no iPhone, so a fixed flight plays instead.
    private let scenario: WatchScenario?
    private let launch = Date.now
    #endif

    init() {
        #if DEBUG
        let scenario = WatchScenario(arguments: ProcessInfo.processInfo.arguments)
        self.scenario = scenario
        if let scenario {
            _model = State(initialValue: WatchFlightModel(state: scenario.initialState(launch: launch)))
            connection = nil
            return
        }
        #endif
        let model = WatchFlightModel()
        _model = State(initialValue: model)
        // Activated at launch so a flight already under way (the application context) shows
        // straight away.
        let connection = PhoneConnection { message in
            model.receive(message)
        }
        connection.activate()
        self.connection = connection
    }

    var body: some Scene {
        WindowGroup {
            WatchFlightView(model: model)
            #if DEBUG
                .task {
                    await scenario?.play(on: model, launch: launch)
                }
            #endif
        }
    }
}
