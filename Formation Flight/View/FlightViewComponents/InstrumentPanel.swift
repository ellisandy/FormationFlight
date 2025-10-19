//
//  InstrumentPanel.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct InstrumentPanel: View {
    @Binding var settingsConfig: SettingsEditorConfig
    @Bindable var panelData: InstrumentPanelData
    @Binding var isFlightViewPresented: Bool
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("5:10")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text("-0:30")
                        .foregroundStyle(.red)
                }.padding(.leading)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("180kn")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text("+10kn")
                        .foregroundStyle(.yellow)
                }.padding(.trailing)
            }
            .padding(.bottom)
            .frame(maxWidth: .infinity)
            .background(.black)
            .opacity(0.9)
            Spacer()
        }

//        Spacer()
        VStack {
            Spacer() // Pushes to the Bottom

            VStack {
                HStack {
                    Button() {
                        // TODO: Add Next waypoint logic here
                    } label: {
                        Text("Next")
                            .font(.title)
                    }
                    .buttonStyle(.bordered)
                    .padding([.top, .leading])
                    
                    Spacer()
                    Button(role: .cancel) {
                        // TODO: Add Winds Update View here
                    } label: {
                        Text("Winds")
                            .font(.title)
                    }
                    .colorInvert()
                    .buttonStyle(.bordered)
                    .padding([.top])
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        isFlightViewPresented.toggle()
                    } label: {
                        Text("End")
                            .font(.title)
                    }
                    .buttonStyle(.bordered)
                    .padding([.top, .trailing])
                }
                .padding(.bottom, 0)

                HStack {
                    InstrumentComponent(infoType: .tot, infoValue: $panelData.currentETA, infoStaus: .good, settingsConfig: $settingsConfig)
                    InstrumentComponent(infoType: .totDrift, infoValue: $panelData.ETADelta, infoStaus: .good, settingsConfig: $settingsConfig)
                    InstrumentComponent(infoType: .course, infoValue: $panelData.course, infoStaus: .nutrual, settingsConfig: $settingsConfig)
                    InstrumentComponent(infoType: .currentTAS, infoValue: $panelData.currentTrueAirspeed, infoStaus: .reallyBad, settingsConfig: $settingsConfig)
                    InstrumentComponent(infoType: .targetTAS, infoValue: $panelData.targetTrueAirspeed, infoStaus: .nutrual , settingsConfig: $settingsConfig)
                    InstrumentComponent(infoType: .targetDistance, infoValue: $panelData.distanceToFinal, infoStaus: .nutrual , settingsConfig: $settingsConfig)
                }
            }
            .frame(maxWidth: .infinity)
            .background(.black)
            .opacity(0.90)
        }
    }
}

#Preview {
    let panelData = InstrumentPanelData(
        currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
        ETADelta: Measurement(value: 600.0, unit: UnitDuration.seconds),
        course: Measurement(value: 180, unit: UnitAngle.degrees),
        currentTrueAirSpeed: Measurement(value: 100, unit: UnitSpeed.metersPerSecond),
        targetTrueAirSpeed: Measurement(value: 100, unit: UnitSpeed.metersPerSecond),
        distanceToNext: Measurement(value: 10, unit: UnitLength.meters),
        distanceToFinal: Measurement(value: 10, unit: UnitLength.meters))
    
    return InstrumentPanel(
        settingsConfig: .constant(SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160)),
        panelData: panelData,
        isFlightViewPresented: .constant(true))
}
