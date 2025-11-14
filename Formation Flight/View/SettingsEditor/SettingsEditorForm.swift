//
//  File.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorForm: View {
    @Binding var settingsEditorConfig: SettingsEditorConfig
    @State private var editMode: EditMode = .active
    
    var body: some View {
        Form {
            Section("Units") {
                Picker("Speed Unit", selection: $settingsEditorConfig.speedUnit) {
                    ForEach(SettingsEditorConfig.SpeedUnit.allCases) { unit in
                        Text(unit.rawValue)
                    }
                }.pickerStyle(.automatic)
                Picker("Distance Unit", selection: $settingsEditorConfig.distanceUnit) {
                    ForEach(SettingsEditorConfig.DistanceUnit.allCases) { unit in
                        Text(unit.rawValue)
                    }
                }.pickerStyle(.automatic)
            }
            
            Section {
                TextField("Yellow Variance", value: $settingsEditorConfig.yellowTolerance, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
                
                TextField("Red Variance", value: $settingsEditorConfig.redTolerance, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
            } header: {
                Text("Time on Target Drift Tolerance")
            } footer: {
                Text("Yellow: +/-\(settingsEditorConfig.yellowTolerance) seconds \nRed:     +/-\(settingsEditorConfig.redTolerance) seconds")
            }
            
            Section("Speed Values") {
                TextField("Minimum Speed", value: $settingsEditorConfig.minSpeed, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
                TextField("Max Speed", value: $settingsEditorConfig.maxSpeed, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
            }
            
            Section {
                TextField("Distance in \(settingsEditorConfig.distanceUnit.rawValue)",
                          value: $settingsEditorConfig.proximityToNextPoint,
                          formatter: doubleFormatter)
                    .keyboardType(.asciiCapableNumberPad)
            } header: {
                Text("Proximity to Next Point")
            } footer: {
                Text("The flight will move on to the next waypoint when it is within \(String(format: "%.2f", arguments: [settingsEditorConfig.proximityToNextPoint])) \(settingsEditorConfig.distanceUnit.rawValue)")
            }
            
            Section("Instruments") {
                if settingsEditorConfig.instrumentSettings.isEmpty {
                    Text("No instruments available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($settingsEditorConfig.instrumentSettings) { $setting in
                        Toggle(isOn: $setting.isEnabled) {
                            Text(setting.type.rawValue)
                        }
                    }
                    .onMove { indices, newOffset in
                        settingsEditorConfig.instrumentSettings.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
    }

    let windDirectionFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = .init(integerLiteral: 0)
        formatter.maximum = .init(integerLiteral: 360)
        formatter.zeroSymbol = ""
        return formatter
    }()
    
    let doubleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = .init(0.1)
        formatter.maximumFractionDigits = 100
        formatter.zeroSymbol = ""
        return formatter
    }()
}

#Preview {
    SettingsEditorForm(settingsEditorConfig: .constant(SettingsEditorConfig.init(speedUnit: .kph, distanceUnit: .nm, yellowTolerance: 10, redTolerance: 20, minSpeed: 0, maxSpeed: 0, proximityToNextPoint: 0.5)))
}

