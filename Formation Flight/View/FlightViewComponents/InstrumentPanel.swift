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
    
    var body: some View {
        VStack {
            Spacer() // Pushes to the Bottom
            HStack {
                Button(role: .cancel) {
                    
                } label: {
                    Text("Next")
                        .font(.title)
                        .padding(.horizontal)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button(role: .destructive) {
                } label: {
                    Text("End")
                        .font(.title)
                        .padding(.horizontal)
                    
                }
                .buttonStyle(.borderedProminent)
                
            }
            
            HStack {
                InstrumentComponent(infoType: .tot, infoValue: $panelData.currentETA, infoStaus: .good, settingsConfig: $settingsConfig)
                InstrumentComponent(infoType: .totDrift, infoValue: $panelData.ETADelta, infoStaus: .good, settingsConfig: $settingsConfig)
                InstrumentComponent(infoType: .course, infoValue: $panelData.course, infoStaus: .nutrual, settingsConfig: $settingsConfig)
                InstrumentComponent(infoType: .currentTAS, infoValue: $panelData.currentTrueAirspeed, infoStaus: .reallyBad, settingsConfig: $settingsConfig)
                InstrumentComponent(infoType: .targetTAS, infoValue: $panelData.targetTrueAirspeed, infoStaus: .nutrual , settingsConfig: $settingsConfig)
                InstrumentComponent(infoType: .targetDistance, infoValue: $panelData.distanceToNext, infoStaus: .nutrual , settingsConfig: $settingsConfig)
            }
            .frame(maxWidth: .infinity)
            .background(.black)
            .opacity(0.85)
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
        settingsConfig: .constant(SettingsEditorConfig(speedUnit: .kph, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160)),
        panelData: panelData)
}
