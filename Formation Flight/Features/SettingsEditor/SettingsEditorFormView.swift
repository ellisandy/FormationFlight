//
//  File.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI
import FormationFlightCore

struct SettingsEditorFormView: View {
    @Bindable var viewModel: SettingsEditorViewModel
    @State private var showsSafetyDisclaimer = false
    @State private var diagnosticStore = DiagnosticSessionStore.shared
    @State private var showsDeleteDiagnosticsConfirmation = false
    @State private var diagnosticsError: String?

    private var preferencesShareFile: PreferencesShareFile? {
        try? PreferencesShareFile(settings: viewModel.settings)
    }

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
            
            // F-01: in-flight callouts. Banners follow the per-event toggles; Voice also speaks them.
            Section {
                Toggle("Voice", isOn: $viewModel.settings.callouts.voiceEnabled)
                    .accessibilityIdentifier("calloutVoiceToggle")
                Toggle("ToT Countdown", isOn: $viewModel.settings.callouts.countdownEnabled)
                    .accessibilityIdentifier("calloutCountdownToggle")
                Toggle("Turn-In Cue", isOn: $viewModel.settings.callouts.turnInEnabled)
                    .accessibilityIdentifier("calloutTurnInToggle")
                Toggle("Drift", isOn: $viewModel.settings.callouts.driftEnabled)
                    .accessibilityIdentifier("calloutDriftToggle")
                Toggle("Speed and GPS", isOn: $viewModel.settings.callouts.speedAndGPSEnabled)
                    .accessibilityIdentifier("calloutSpeedToggle")
                Stepper(value: Binding(
                    get: { viewModel.speedThresholdDisplay },
                    set: { viewModel.setSpeedThreshold(display: $0) }
                ), in: viewModel.speedThresholdRange, step: 1) {
                    Text("Speed Advisory ±\(viewModel.speedThresholdDisplay) \(viewModel.settings.speedUnit.symbol)")
                }
                .disabled(!viewModel.settings.callouts.speedAndGPSEnabled)
                .accessibilityIdentifier("calloutSpeedThresholdStepper")
            } header: {
                Text("Callouts")
            } footer: {
                Text("Callouts appear as a banner on the flight screen. With Voice on they are also spoken, even when the phone is set to silent, and other audio is lowered while they play. A speed advisory is given when required and current ground speed differ by at least the amount set, while outside the yellow tolerance.")
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

            Section {
                Toggle("Diagnostics Mode", isOn: $viewModel.diagnosticsEnabled)
                    .accessibilityIdentifier("diagnosticsModeToggle")

                if diagnosticStore.sessions.isEmpty {
                    Text("No diagnostic flights recorded in the last 14 days.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(diagnosticStore.sessions) { session in
                        ShareLink(
                            item: DiagnosticShareFile(fileURL: session.fileURL),
                            preview: SharePreview(session.missionName)
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.missionName)
                                    .foregroundStyle(.primary)
                                Text(session.startedAt, format: .dateTime.month().day().year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Flight time: \(formattedDuration(session.durationSeconds))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Share diagnostics for \(session.missionName)")
                    }

                    Button("Delete All Diagnostics", role: .destructive) {
                        showsDeleteDiagnosticsConfirmation = true
                    }
                    .accessibilityIdentifier("deleteAllDiagnosticsButton")
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("When enabled, each flight records precise location, timing calculations, and app decisions. Select a recent flight to share its JSON report. Reports are deleted after 14 days.")
            }

            Section("Transfer") {
                if let preferencesShareFile {
                    ShareLink(
                        item: preferencesShareFile,
                        preview: SharePreview("Formation Flight Preferences")
                    ) {
                        Label("Share Preferences", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("sharePreferencesButton")
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
        .onAppear {
            diagnosticStore.refresh()
        }
        .alert("Delete All Diagnostics?", isPresented: $showsDeleteDiagnosticsConfirmation) {
            Button("Delete", role: .destructive) {
                do {
                    try diagnosticStore.deleteAll()
                } catch {
                    diagnosticsError = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes every saved diagnostic flight.")
        }
        .alert(
            "Could Not Delete Diagnostics",
            isPresented: Binding(
                get: { diagnosticsError != nil },
                set: { isPresented in
                    if !isPresented {
                        Task { @MainActor in diagnosticsError = nil }
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(diagnosticsError ?? "")
        }
        .sheet(isPresented: $showsSafetyDisclaimer) {
            // Read-only re-display: the pilot already acknowledged at first
            // launch, so the button simply dismisses.
            SafetyDisclaimerView {
                showsSafetyDisclaimer = false
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    SettingsEditorFormView(viewModel: SettingsEditorViewModel())
}

