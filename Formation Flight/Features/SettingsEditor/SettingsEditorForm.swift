//
//  File.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorForm: View {
    @ObservedObject var viewModel: SettingsEditorViewModel
    @State private var editMode: EditMode = .active
    
    var body: some View {
        Form {
            Section("Units") {
                Picker("Speed Unit", selection: $viewModel.settings.speedUnit) {
                    ForEach(Settings.SpeedUnit.allCases) { unit in
                        Text(unit.rawValue)
                    }
                }.pickerStyle(.automatic)
                Picker("Distance Unit", selection: $viewModel.settings.distanceUnit) {
                    ForEach(Settings.DistanceUnit.allCases) { unit in
                        Text(unit.rawValue)
                    }
                }.pickerStyle(.automatic)
            }
            
            Section {
                TextField("Yellow Variance", value: $viewModel.settings.yellowTolerance, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
                
                TextField("Red Variance", value: $viewModel.settings.redTolerance, formatter: windDirectionFormatter)
                    .keyboardType(.numberPad)
            } header: {
                Text("Time on Target Drift Tolerance")
            } footer: {
                Text("Yellow: +/-\(viewModel.settings.yellowTolerance) seconds \nRed:     +/-\(viewModel.settings.redTolerance) seconds")
            }
            
            Section("Instruments") {
                if viewModel.settings.instrumentSettings.isEmpty {
                    Text("No instruments available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($viewModel.settings.instrumentSettings) { $setting in
                        Toggle(isOn: $setting.isEnabled) {
                            Text(setting.type.rawValue)
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.settings.instrumentSettings.move(fromOffsets: indices, toOffset: newOffset)
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
    SettingsEditorForm(viewModel: SettingsEditorViewModel())
}

