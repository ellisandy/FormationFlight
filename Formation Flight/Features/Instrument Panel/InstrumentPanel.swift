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
    // View Controls
    @Binding var isFlightViewPresented: Bool
    
    // View Data Sources
    @Binding var settingsConfig: SettingsEditorConfig
    @State var panelData: InstrumentPanelData = InstrumentPanelData.emptyPanel()
    @Binding var flight: Flight
    
    // Wind Update Vars
    @State var showWindAlert = false
    @State var tempWindSpeed: String = ""
    @State var tempWindDirection: String = ""

    // Data Providers
    private let locationProvider = LocationProvider()
    private let uiUpdateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var orderedInstruments: [InstrumentSpec] {
        settingsConfig.instrumentSettings
            .filter { $0.isEnabled }
            .map { setting in
                switch setting.type {
                case .tot:
                    return InstrumentSpec(type: .tot, status: .nutrual, value: $panelData.currentETA)
                case .totDrift:
                    return InstrumentSpec(type: .totDrift, status: InstrumentPanelCalculator.etaDriftStatus(delta: panelData.ETADelta, yellowTolerance: Double(settingsConfig.yellowTolerance), redTolerance: Double(settingsConfig.redTolerance)), value: $panelData.ETADelta)
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
                case .expectedWindsDirection:
                    return InstrumentSpec(type: .expectedWindsDirection, status: .nutrual, value: $panelData.expectedWindDirection)
                case .expectedWindsVelocity:
                    return InstrumentSpec(type: .expectedWindsVelocity, status: .nutrual, value: $panelData.expectedWindVelocity)
                }
            }
    }
    
    var body: some View {
        VStack {
            VStack {
                ForEach(Array(orderedInstruments.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                    CenteredInstrumentRow(specs: row, settingsConfig: $settingsConfig)
                }
                Button(role: .confirm) {
                    if flight.inflightCheckPoints.count > 1 {
                        flight.inflightCheckPoints.removeFirst()
                    }
                } label: {
                    HStack {
                        Text("D\u{2192}")
                            .font(.title)
                            .tracking(-3)
                        Text("\(flight.inflightCheckPoints.first?.name ?? "Next")")
                                .font(.title)

                    }
                    .frame(maxWidth: .infinity)
//                    .padding(.horizontal)
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
    
    func calculateTheStuff() -> Void {
        // If no user location available, just bail out
        guard let location = locationProvider.locationManager.location else { return }
        
        let updated = InstrumentPanelCalculator.updatePanel(currentLocation: location, flight: flight, config: settingsConfig, existing: panelData)
        self.panelData = updated
    }
}


#Preview {
    InstrumentPanel(isFlightViewPresented: Binding.constant(true),
                    settingsConfig: .constant(SettingsEditorConfig(speedUnit: .kts,
                                                                   distanceUnit: .nm,
                                                                   yellowTolerance: 5,
                                                                   redTolerance: 10,
                                                                   minSpeed: 100,
                                                                   maxSpeed: 160,
                                                                   proximityToNextPoint: 0.5)),
                    flight: .constant(Flight.emptyFlight()))
}

