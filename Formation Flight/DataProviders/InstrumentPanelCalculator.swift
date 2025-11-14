import Foundation
import MapKit

struct InstrumentPanelCalculator {
    static func makeData(currentLocation: CLLocation, flight: Flight, config: SettingsEditorConfig) -> InstrumentPanelData {
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
        
        var bearingNext: Measurement<UnitAngle>? = nil
        var bearingLast: Measurement<UnitAngle>? = nil
        
        if let destinationNext = destinations.first {
            bearingNext = currentLocation.getBearing(to: destinationNext)
        }
        if let destinationLast = destinations.last, destinations.count > 1 {
            bearingLast = currentLocation.getBearing(to: destinationLast)
        }
        
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
            bearingFinal: bearingLast?.erasedType,
            expectedWindVelocity: flight.expectedWinds.velocity.erasedType,
            expectedWindDirection: flight.expectedWinds.direction.erasedType
        )
    }
    
    static func updatePanel(currentLocation: CLLocation, flight: Flight, config: SettingsEditorConfig, existing: InstrumentPanelData) -> InstrumentPanelData {
        // Recalculate panel data
        let temp = makeData(currentLocation: currentLocation, flight: flight, config: config)

        // Auto-advance checkpoint if within proximity and more than one remains
        if let nextCheckpoint = flight.inflightCheckPoints.first {
            let distanceToNextInMeters = currentLocation.distance(from: nextCheckpoint.getCLLocation())
            let proximityToAutoNext: Measurement<UnitLength> = Measurement(value: config.proximityToNextPoint, unit: config.getDistanceUnits())
            if distanceToNextInMeters < proximityToAutoNext.converted(to: .meters).value, flight.inflightCheckPoints.count > 1 {
                flight.inflightCheckPoints.removeFirst()
            }
        }

        // Mutate only changed fields on the provided existing data to minimize updates
        if existing.currentETA != temp.currentETA { existing.currentETA = temp.currentETA }
        if existing.ETADelta != temp.ETADelta { existing.ETADelta = temp.ETADelta }
        if existing.bearingNext != temp.bearingNext { existing.bearingNext = temp.bearingNext }
        if existing.bearingFinal != temp.bearingFinal { existing.bearingFinal = temp.bearingFinal }
        if existing.groundSpeed != temp.groundSpeed { existing.groundSpeed = temp.groundSpeed }
        if existing.currentTrueAirspeed != temp.currentTrueAirspeed { existing.currentTrueAirspeed = temp.currentTrueAirspeed }
        if existing.targetTrueAirspeed != temp.targetTrueAirspeed { existing.targetTrueAirspeed = temp.targetTrueAirspeed }
        if existing.distanceToNext != temp.distanceToNext { existing.distanceToNext = temp.distanceToNext }
        if existing.distanceToFinal != temp.distanceToFinal { existing.distanceToFinal = temp.distanceToFinal }
        if existing.expectedWindVelocity != temp.expectedWindVelocity { existing.expectedWindVelocity = temp.expectedWindVelocity }
        if existing.expectedWindDirection != temp.expectedWindDirection { existing.expectedWindDirection = temp.expectedWindDirection }

        return existing
    }
    
    static func etaDriftStatus(delta: Measurement<Dimension>?, yellowTolerance: Double, redTolerance: Double) -> InfoStatus {
        // Validate delta and is UnitDuration or return .nutrual
        guard let delta else { return .nutrual }
        if !(delta.unit is UnitDuration) { return .nutrual }
        
        let secondsValue = delta.converted(to: UnitDuration.seconds).value
        let absValue: Double = abs(secondsValue) / 60.0

        let yellow = yellowTolerance
        let red = redTolerance

        if absValue < yellow { return .good }
        if absValue < red { return .bad }
        return .reallyBad
    }
}
