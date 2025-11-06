//
//  InstrumentPanel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

// MARK: - Data-driven instruments support
struct InstrumentSpec: Identifiable {
    var id: String { String(describing: type) }
    let type: InFlightInfo
    let status: InfoStatus
    let value: Binding<Measurement<Dimension>?>
}

struct CenteredInstrumentRow: View {
    let specs: [InstrumentSpec]
    @Binding var settingsConfig: SettingsEditorConfig

    var body: some View {
        HStack {
            Spacer()
            ForEach(Array(specs.enumerated()), id: \.element.id) { index, spec in
                InstrumentComponent(
                    infoType: spec.type,
                    infoValue: spec.value,
                    infoStaus: spec.status,
                    settingsConfig: $settingsConfig
                )
                if index < specs.count - 1 {
                    Spacer()
                }
            }
            Spacer()
        }
    }
}

struct InstrumentPanel: View {
    @Binding var settingsConfig: SettingsEditorConfig
    @State var panelData: InstrumentPanelData = InstrumentPanelData.emptyPanel()
    @Binding var isFlightViewPresented: Bool
    @Binding var flight: Flight
    @State var showWindAlert = false
    @State var tempWindSpeed: String = ""
    @State var tempWindDirection: String = ""

    
    private let locationProvider = LocationProvider()
    private let uiUpdateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    // Order can later be driven from user settings
    var orderedInstruments: [InstrumentSpec] {
        settingsConfig.instrumentSettings
            .filter { $0.isEnabled }
            .map { setting in
                switch setting.type {
                case .tot:
                    return InstrumentSpec(type: .tot, status: .good, value: $panelData.currentETA)
                case .totDrift:
                    return InstrumentSpec(
                        type: .totDrift,
                        status: statusForETADrift(panelData.ETADelta),
                        value: $panelData.ETADelta
                    )
                case .nextBearing:
                    return InstrumentSpec(type: .nextBearing, status: .nutrual, value: $panelData.bearingNext)
                case .currentTAS:
                    return InstrumentSpec(type: .currentTAS, status: .nutrual, value: $panelData.currentTrueAirspeed)
                case .targetTAS:
                    return InstrumentSpec(type: .targetTAS, status: .nutrual, value: $panelData.targetTrueAirspeed)
                case .distanceToFinal:
                    return InstrumentSpec(type: .distanceToFinal, status: .nutrual, value: $panelData.distanceToFinal)
                case .distanceToNext:
                    return InstrumentSpec(type: .distanceToNext, status: .nutrual, value: $panelData.distanceToNext)
                case .finalBearing:
                    return InstrumentSpec(type: .finalBearing, status: .nutrual, value: $panelData.bearingFinal)
                case .groundSpeed:
                    return InstrumentSpec(type: .groundSpeed, status: .nutrual, value: $panelData.groundSpeed)
                }
            }
    }
    
    // Determines status for ETA drift based on settings thresholds
    private func statusForETADrift(_ delta: Measurement<Dimension>?) -> InfoStatus {
        // Validate delta and is UnitDuration or return .nutrual
        guard let delta else { return .nutrual }
        if !(delta.unit is UnitDuration) { return .nutrual }
        
        let secondsValue = delta.converted(to: UnitDuration.seconds).value
        let absValue: Double = abs(secondsValue) / 60.0

        let yellow = Double(settingsConfig.yellowTolerance)
        let red = Double(settingsConfig.redTolerance)

        if absValue < yellow { return .good }
        if absValue < red { return .bad }
        return .reallyBad
    }
    
    var body: some View {
        VStack {
            VStack {
                ForEach(orderedInstruments.chunked(into: 3), id: \.first!.id) { row in
                    CenteredInstrumentRow(specs: row, settingsConfig: $settingsConfig)
                }
                Button(role: .confirm) {
                    if flight.inflightCheckPoints.count > 1 {
                        flight.inflightCheckPoints.removeFirst()
                    }
                } label: {
                    Text("Next Checkpoint")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button(role: .confirm) {
                    let currentTime = Date()
                    let markTimeInSeconds = flight.markTimeInSeconds ?? 60.0
                    flight.missionDate = currentTime.advanced(by: markTimeInSeconds)
                } label: {
                    Text("T+ \(String(flight.markTimeInSeconds ?? 60.0)) ToT")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button(role: .confirm) {
                    showWindAlert.toggle()
                } label: {
                    Text("Winds")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .alert("Winds", isPresented: $showWindAlert) {
                    TextField("Wind Direction", text: $tempWindDirection)
                        .keyboardType(.numberPad)
                    TextField("Wind Velocity", text: $tempWindSpeed)
                        .keyboardType(.numberPad)
                    Button("Update") {
                        if $tempWindSpeed.wrappedValue.isEmpty == false {
                            if let windSpeed = Double($tempWindSpeed.wrappedValue) {
                                flight.expectedWinds.velocity = Measurement(value: windSpeed, unit: settingsConfig.getUnitSpeed())
                            }
                        }
                        
                        if $tempWindDirection.wrappedValue.isEmpty == false {
                            if let windDirection = Double($tempWindDirection.wrappedValue) {
                                flight.expectedWinds.direction = Measurement(value: windDirection, unit: .degrees)

                            }
                        }
                        
                        showWindAlert.toggle()
                    }
                    Button("Cancel") {
                        tempWindSpeed = ""
                        tempWindDirection = ""
                        showWindAlert.toggle()
                    }
                } message: {
                    Text("Update Winds")
                }
                Button(role: .destructive) {
                    $isFlightViewPresented.wrappedValue = false
                } label: {
                    Text("End")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .onReceive(uiUpdateTimer) { _ in
            calculateTheStuff()
        }
    }
    
    // TODO: Clean this up?
    // The general idea... I think will be to pull the new data, then have some type of copy functino to move the core logic out
    // of the view file.
    func calculateTheStuff() -> Void {
        // TODO: Check current location and potentially remove the checkpoint when within a certain area
        guard let location = locationProvider.locationManager.location else { return }
        
        // Calculate how close to the next point
        let distanceToNextInMeters = location.distance(from: flight.inflightCheckPoints.first!.getCLLocation())
        let proximityToAutoNext: Measurement<UnitLength> = Measurement(value: settingsConfig.proximityToNextPoint, unit: settingsConfig.getDistanceUnits())
        
        
        if distanceToNextInMeters < proximityToAutoNext.converted(to: .meters).value, flight.inflightCheckPoints.count > 1 {
            flight.inflightCheckPoints.removeFirst()
        }
            
        let temp = flight.provideInstrumentPanelData(from: location)
        
        if panelData.currentETA != temp.currentETA { panelData.currentETA = temp.currentETA }
        if panelData.ETADelta != temp.ETADelta { panelData.ETADelta = temp.ETADelta }
        if panelData.bearingNext != temp.bearingNext { panelData.bearingNext = temp.bearingNext }
        if panelData.bearingFinal != temp.bearingFinal { panelData.bearingFinal = temp.bearingFinal }
        if panelData.groundSpeed != temp.groundSpeed { panelData.groundSpeed = temp.groundSpeed }
        if panelData.currentTrueAirspeed != temp.currentTrueAirspeed { panelData.currentTrueAirspeed = temp.currentTrueAirspeed }
        if panelData.targetTrueAirspeed != temp.targetTrueAirspeed { panelData.targetTrueAirspeed = temp.targetTrueAirspeed }
        if panelData.distanceToNext != temp.distanceToNext { panelData.distanceToNext = temp.distanceToNext }
        if panelData.distanceToFinal != temp.distanceToFinal { panelData.distanceToFinal = temp.distanceToFinal }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var chunks: [[Element]] = []
        var start = 0
        while start < count {
            let end = Swift.min(start + size, count)
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
}

#Preview {
    InstrumentPanel(settingsConfig: .constant(SettingsEditorConfig(speedUnit: .kts,
                                                                   distanceUnit: .nm,
                                                                   yellowTolerance: 5,
                                                                   redTolerance: 10,
                                                                   minSpeed: 100,
                                                                   maxSpeed: 160,
                                                                   proximityToNextPoint: 0.5)),
                    isFlightViewPresented: Binding.constant(true),
                    flight: .constant(Flight.emptyFlight()))
}

