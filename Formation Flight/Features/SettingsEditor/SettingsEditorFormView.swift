//
//  File.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorFormView: View {
    @ObservedObject var viewModel: SettingsEditorViewModel
    @State private var editMode: EditMode = .active
    @State private var showsSafetyDisclaimer = false

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

            // R-07: persistent safety reminder plus a way to re-read the full
            // disclaimer after the first-launch acknowledgement.
            Section {
                Button("Show Safety Disclaimer") {
                    showsSafetyDisclaimer = true
                }
                .accessibilityIdentifier("settingsShowDisclaimerButton")
            } header: {
                Text("Safety")
            } footer: {
                Text(SafetyDisclaimer.settingsFooter)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settingsSafetyDisclaimerText")
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showsSafetyDisclaimer) {
            // Read-only re-display: the pilot already acknowledged at first
            // launch, so the button simply dismisses.
            SafetyDisclaimerView {
                showsSafetyDisclaimer = false
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
    SettingsEditorFormView(viewModel: SettingsEditorViewModel())
}

