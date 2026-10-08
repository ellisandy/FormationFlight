//
//  File.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorFormView: View {
    @Bindable var viewModel: SettingsEditorViewModel
    @State private var showsSafetyDisclaimer = false

    var body: some View {
        Form {
            Section("Units") {
                Picker("Speed Unit", selection: $viewModel.settings.speedUnit) {
                    ForEach(Settings.SpeedUnit.allCases) { unit in
                        Text(unit.symbol)
                    }
                }.pickerStyle(.automatic)
                Picker("Distance Unit", selection: $viewModel.settings.distanceUnit) {
                    ForEach(Settings.DistanceUnit.allCases) { unit in
                        Text(unit.symbol)
                    }
                }.pickerStyle(.automatic)
            }
            
            // B-13: steppers commit on every tap. The number-pad text fields they replace
            // had no return key, so a typed value never reached the model before Save.
            Section {
                Stepper(value: Binding(
                    get: { viewModel.settings.yellowTolerance },
                    set: { viewModel.setYellowTolerance($0) }
                ), in: SettingsEditorViewModel.toleranceRange, step: 1) {
                    Text("Yellow ±\(viewModel.settings.yellowTolerance) s")
                }
                .accessibilityIdentifier("yellowToleranceStepper")

                Stepper(value: Binding(
                    get: { viewModel.settings.redTolerance },
                    set: { viewModel.setRedTolerance($0) }
                ), in: SettingsEditorViewModel.toleranceRange, step: 1) {
                    Text("Red ±\(viewModel.settings.redTolerance) s")
                }
                .accessibilityIdentifier("redToleranceStepper")
            } header: {
                Text("Time on Target Drift Tolerance")
            } footer: {
                Text("Seconds early or late before the time-on-target readout turns yellow, then red. Red is never below yellow.")
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
        .readableScrollContent()
        .sheet(isPresented: $showsSafetyDisclaimer) {
            // Read-only re-display: the pilot already acknowledged at first
            // launch, so the button simply dismisses.
            SafetyDisclaimerView {
                showsSafetyDisclaimer = false
            }
        }
    }
}

#Preview {
    SettingsEditorFormView(viewModel: SettingsEditorViewModel())
}

