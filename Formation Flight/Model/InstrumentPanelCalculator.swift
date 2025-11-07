import Foundation
import MapKit

struct InstrumentPanelCalculator {
    static func makeData(currentLocation: CLLocation, flight: Flight) -> InstrumentPanelData {
        // Compute mission TOT relative to now
        let tot = Date.now.secondsUntil(time: flight.missionDate).secondsMeasurement

        // Build destination locations from flight checkpoints
        let destinations: [CLLocation] = flight.getCLLocations()

        let distanceFinal: Measurement<UnitLength>? = currentLocation.distance(from: destinations)?.metersMeasurement
        let distanceNext: Measurement<UnitLength>? = destinations.first?.distance(from: currentLocation)

        var etaDelta: Double? = nil
        if let actualTOT = currentLocation.getTime(to: destinations, with: flight.expectedWinds) {
            etaDelta = actualTOT.converted(to: .seconds).value - tot.converted(to: .seconds).value
        }

        let targetAirspeed: Measurement<UnitSpeed>? = currentLocation.getTargetAirspeed(tot: tot, destinations: destinations, winds: flight.expectedWinds)

        let currentTrueAirSpeed = currentLocation.getTrueAirSpeed(with: flight.expectedWinds)
        let bearingNext = currentLocation.getBearing(to: destinations.first!)
        let bearingFinal = currentLocation.getBearing(to: destinations.last!)
        let groundSpeed: Measurement<UnitSpeed>? = Measurement(value: currentLocation.speed, unit: .metersPerSecond)

        return InstrumentPanelData(
            currentETA: tot.erasedType,
            ETADelta: etaDelta?.secondsMeasurement.erasedType,
            bearingNext: bearingNext?.erasedType,
            currentTrueAirSpeed: currentTrueAirSpeed?.erasedType,
            targetTrueAirSpeed: targetAirspeed?.erasedType,
            distanceToNext: distanceNext?.erasedType,
            distanceToFinal: distanceFinal?.erasedType,
            groundSpeed: groundSpeed?.erasedType,
            bearingFinal: bearingFinal?.erasedType
        )
    }
}
