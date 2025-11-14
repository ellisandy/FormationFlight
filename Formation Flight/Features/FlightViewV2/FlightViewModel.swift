//
//  FlightViewModel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/13/25.
//

import Foundation
@preconcurrency import Combine
import CoreLocation

@MainActor
final class FlightViewModel: ObservableObject {
    // Timing
    @Published var currentTime: Date
    @Published var ete: TimeInterval
    @Published var eta: Date
    @Published var delta: TimeInterval
    @Published var tot: Date

    // Instruments
    @Published var currentGroundSpeed: Measurement<UnitSpeed>
    @Published var requiredGroundSpeed: Measurement<UnitSpeed>
    @Published var distance: Measurement<UnitLength>
    @Published var bearing: Double // degrees
    @Published var track: Double   // degrees
    @Published var windDirection: Double // degrees (0-360)
    @Published var windSpeed: Measurement<UnitSpeed>

    // Mission details
    @Published var targetName: String
    @Published var coordinate: CLLocationCoordinate2D
    @Published var missionTOT: Date

    private var timerCancellable: AnyCancellable?

    init(
        currentTime: Date = .now,
        ete: TimeInterval = 104,
        eta: Date = .now.addingTimeInterval(-14),
        delta: TimeInterval = 4,
        tot: Date = Calendar.current.date(bySettingHour: 9, minute: 50, second: 0, of: .now) ?? .now,
        currentGroundSpeed: Measurement<UnitSpeed> = .init(value: 120, unit: .knots),
        requiredGroundSpeed: Measurement<UnitSpeed> = .init(value: 100, unit: .knots),
        distance: Measurement<UnitLength> = .init(value: 3.5, unit: .nauticalMiles),
        bearing: Double = 175,
        track: Double = 178,
        windDirection: Double = 140,
        windSpeed: Measurement<UnitSpeed> = .init(value: 21, unit: .knots),
        targetName: String = "Eagles Nest",
        coordinate: CLLocationCoordinate2D = .init(latitude: 32.4666667, longitude: -96.9945),
        missionTOT: Date = Calendar.current.date(bySettingHour: 9, minute: 50, second: 0, of: .now) ?? .now
    ) {
        self.currentTime = currentTime
        self.ete = ete
        self.eta = eta
        self.delta = delta
        self.tot = tot
        self.currentGroundSpeed = currentGroundSpeed
        self.requiredGroundSpeed = requiredGroundSpeed
        self.distance = distance
        self.bearing = bearing
        self.track = track
        self.windDirection = windDirection
        self.windSpeed = windSpeed
        self.targetName = targetName
        self.coordinate = coordinate
        self.missionTOT = missionTOT

        startTimer()
    }

    private func startTimer() {
        // Update every second on the main run loop
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.currentTime = Date()
            }
    }

    deinit {
        timerCancellable?.cancel()
    }
}

