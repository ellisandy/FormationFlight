//
//  InstrumentPanel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct InstrumentPanel: View {
    @Binding var settingsConfig: SettingsEditorConfig
    @State var panelData: InstrumentPanelData = InstrumentPanelData.emptyPanel()
    @Binding var isFlightViewPresented: Bool
    @Binding var flight: Flight?
    
    private let locationProvider = LocationProvider()
    private let uiUpdateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Spacer()
                    InstrumentComponent(infoType: .tot,
                                        infoValue: $panelData.currentETA,
                                        infoStaus: .good,
                                        settingsConfig: $settingsConfig)
                    Spacer()
                    InstrumentComponent(infoType: .totDrift,
                                        infoValue: $panelData.ETADelta,
                                        infoStaus: .good,
                                        settingsConfig: $settingsConfig)
                    Spacer()
                    InstrumentComponent(infoType: .course,
                                        infoValue: $panelData.course,
                                        infoStaus: .nutrual,
                                        settingsConfig: $settingsConfig)
                    Spacer()
                }
                HStack {
                    Spacer()
                    InstrumentComponent(infoType: .currentTAS,
                                        infoValue: $panelData.currentTrueAirspeed,
                                        infoStaus: .reallyBad,
                                        settingsConfig: $settingsConfig)
                    Spacer()
                    InstrumentComponent(infoType: .targetTAS,
                                        infoValue: $panelData.targetTrueAirspeed,
                                        infoStaus: .nutrual,
                                        settingsConfig: $settingsConfig)
                    Spacer()
                    InstrumentComponent(infoType: .targetDistance,
                                        infoValue: $panelData.distanceToFinal,
                                        infoStaus: .nutrual,
                                        settingsConfig: $settingsConfig)
                    Spacer()
                }
                Button(role: .confirm) {
                    $isFlightViewPresented.wrappedValue = false
                } label: {
                    Text("Next Checkpoint")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                Button(role: .confirm) {
                    $isFlightViewPresented.wrappedValue = false
                } label: {
                    Text("Winds")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
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
        
        guard let temp = flight?.provideInstrumentPanelData(from: location) else { return }
        
        panelData.currentETA = temp.currentETA
        panelData.ETADelta = temp.ETADelta
        panelData.course = temp.course
        panelData.currentTrueAirspeed = temp.currentTrueAirspeed
        panelData.targetTrueAirspeed = temp.targetTrueAirspeed
        panelData.distanceToNext = temp.distanceToNext
        panelData.distanceToFinal = temp.distanceToFinal        
    }
}

#Preview {

 InstrumentPanel(settingsConfig: .constant(SettingsEditorConfig(speedUnit: .kts,
                                                                          distanceUnit: .nm,
                                                                          yellowTolerance: 5,
                                                                          redTolerance: 10,
                                                                          minSpeed: 100,
                                                                          maxSpeed: 160)),
                           isFlightViewPresented: Binding.constant(true),
                           flight: .constant(Flight.emptyFlight()))
}

