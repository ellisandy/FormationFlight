//
//  File.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorForm: View {
    @Binding var settingsEditorConfig: SettingsEditorConfig
    
    var body: some View {
        
        Form {
            Section("Speed Unit") {
                Picker("Speed Unit", selection: $settingsEditorConfig.speedUnit) {
                    ForEach(SettingsEditorConfig.SpeedUnit.allCases) { unit in
                        Text(unit.rawValue.uppercased())
                    }
                }.pickerStyle(.segmented)
            }
            Section("Time on Target Drift Tolerance") {
                
                TextField("Yellow Variance", value: $settingsEditorConfig.yellowTolerance, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
                
                TextField("Yellow Red", value: $settingsEditorConfig.redTolerance, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
            }
            Section("Speed Values") {
                TextField("Minimum Speed", value: $settingsEditorConfig.minSpeed, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
                TextField("Max Speed", value: $settingsEditorConfig.maxSpeed, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
            }
            
        }
        
    }
    let windDirectionFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = .init(integerLiteral: 0)
        formatter.maximum = .init(integerLiteral: 360)
        formatter.zeroSymbol = ""
        return formatter
    }()
}

#Preview {
    SettingsEditorForm(settingsEditorConfig: .constant(SettingsEditorConfig.init(speedUnit: .kph, yellowTolerance: 0, redTolerance: 0, minSpeed: 0, maxSpeed: 0)))
}
