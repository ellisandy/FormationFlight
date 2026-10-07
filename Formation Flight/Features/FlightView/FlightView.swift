//
//  FlightViewV2.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/12/25.
//

import SwiftUI
import UIKit
import CoreLocation

private struct LabelValueRow: View {
    let label: String
    let value: String?
    var valueColor: Color? = nil
    /// Accessibility identifier for the combined row, used by UI tests.
    var identifier: String? = nil

    var body: some View {
        HStack {
            Text(label).font(.title)
            Spacer()
            Text(value ?? "")
                .font(.title)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
                // Readouts must stay on one line at large Dynamic Type sizes;
                // shrink the value rather than wrapping or clipping it.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, Design.Padding.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
    }
}

private struct InstrumentCard: View {
    let title: String
    let value: String?
    var valueColor: Color? = nil
    var verticalPadding: CGFloat = 10
    var titleFont: Font = .title2
    var valueFont: Font = .title
    /// Accessibility identifier for the combined card, used by UI tests.
    var identifier: String? = nil

    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(titleFont)
            Text(value ?? "---")
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
                // Readouts must stay on one line at large Dynamic Type sizes;
                // shrink the value rather than wrapping or clipping it.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .cardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "---")
    }
}

// MARK: - Private Subviews

private struct TimingSection: View {
    let time: String
    let ete: String
    let eta: String
    let delta: String
    let tot: String
    let emphasisColor: Color
    
    var body: some View {
        VStack {
            LabelValueRow(label: "Time", value: time, identifier: "timingTimeRow")
                .padding(.top, 10)

            LabelValueRow(label: "ETE", value: ete, identifier: "timingETERow")
            LabelValueRow(label: "ETA", value: eta, valueColor: emphasisColor, identifier: "timingETARow")
            LabelValueRow(label: "Δ", value: delta, valueColor: emphasisColor, identifier: "timingDeltaRow")
            LabelValueRow(label: "TOT", value: tot, identifier: "timingTOTRow")
                .padding(.bottom, 10)
        }
        .cardBackground()
        .padding(.horizontal, Design.Padding.horizontal)
    }
}

private struct InstrumentsSection: View {
    let curGS: String
    let reqGS: String
    let dist: String
    let emphasisColor: Color
    
    // Inputs for bearing/track
    let curBrg: String
    let curTrk: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                InstrumentCard(title: "Cur GS", value: curGS, valueColor: emphasisColor, identifier: "instrumentCurGS")
                InstrumentCard(title: "Req GS", value: reqGS, valueColor: emphasisColor, identifier: "instrumentReqGS")
                InstrumentCard(title: "Dist", value: dist, identifier: "instrumentDist")
            }
            .padding(.horizontal, Design.Padding.horizontal)
            .padding(.vertical, 5)

            HStack(spacing: 5) {
                InstrumentCard(title: "Brg", value: curBrg, verticalPadding: 5, titleFont: .title2, valueFont: .title, identifier: "instrumentBrg")
                InstrumentCard(title: "Trk", value: curTrk, verticalPadding: 5, titleFont: .title2, valueFont: .title, identifier: "instrumentTrk")
            }
            .padding(.horizontal, Design.Padding.horizontal)
            .padding(.vertical, 5)
        }
    }
}

private struct MissionDetailsSection: View {
    let targetName: String?
    let latitude: String
    let longitude: String
    let isHackTime: Bool
    let hackTime: String
    let tot: String
    
    var body: some View {
        VStack {
            LabelValueRow(label: "Target", value: targetName)
                .padding(.top, 10)
            LabelValueRow(label: "Latitude", value: latitude)
            LabelValueRow(label: "Longitude", value: longitude)
            if isHackTime {
                LabelValueRow(label: "Hack Time", value: hackTime)
                    .padding(.bottom, 10)
            } else {
                LabelValueRow(label: "TOT", value: tot)
                    .padding(.bottom, 10)
            }
        }
        .cardBackground()
        .padding(.horizontal, Design.Padding.horizontal)
    }
}

// MARK: - Main View

struct FlightView: View {
    @StateObject private var viewModel: FlightViewModel
    @State private var showEndFlightConfirm = false
    @Environment(\.dismiss) private var dismiss
    
    /// Takes the view model as an autoclosure so construction is deferred into
    /// `StateObject(wrappedValue:)`, which SwiftUI evaluates exactly once for the
    /// lifetime of the view. Without this, every re-evaluation of the presenting
    /// `fullScreenCover` closure would build a throwaway `FlightViewModel`.
    init(viewModel: @autoclosure @escaping () -> FlightViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    HStack {
                        Text("Timing").font(.largeTitle.bold())
                    }
                    .padding(.horizontal, Design.Padding.horizontal)
                    .padding(.bottom, 10)
                    
                    TimingSection(
                        time: Formatting.timeHHmmss(viewModel.currentTime),
                        ete: Formatting.durationHMS(viewModel.ete),
                        eta: Formatting.timeHHmmss(viewModel.eta),
                        delta: Formatting.signedDurationHMS(viewModel.delta),
                        tot: Formatting.timeHHmmss(viewModel.tot),
                        emphasisColor: viewModel.statusColor.color
                    )
                    
                    HStack {
                        Text("Instruments").font(.largeTitle.bold())
                    }
                    .padding(.horizontal, Design.Padding.horizontal)
                    .padding(.vertical, 10)
                    
                    let speedStr: (Measurement<UnitSpeed>?) -> String = { m in
                        MeasurementFormatters.speedString(m, unitPreference: viewModel.settings.speedUnit)
                    }
                    let distanceStr: (Measurement<UnitLength>?) -> String = { m in
                        MeasurementFormatters.distanceString(m, unitPreference: viewModel.settings.distanceUnit)
                    }
                    
                    InstrumentsSection(
                        curGS: speedStr(viewModel.currentGroundSpeed),
                        reqGS: speedStr(viewModel.requiredGroundSpeed),
                        dist: distanceStr(viewModel.distance),
                        emphasisColor: viewModel.statusColor.color,
                        curBrg: Formatting.angle(viewModel.bearing),
                        curTrk: Formatting.angle(viewModel.track)
                    )
                    
                    Text("Mission Details").font(.largeTitle.bold())
                        .padding(.horizontal, Design.Padding.horizontal)
                        .padding(.vertical, 5)
                    
                    MissionDetailsSection(
                        targetName: viewModel.missionName,
                        latitude: Formatting.dms(from: viewModel.target).lat,
                        longitude: Formatting.dms(from: viewModel.target).lon,
                        isHackTime: viewModel.missionType == .hackTime,
                        hackTime: Formatting.durationHMS(viewModel.hackTime),
                        tot: Formatting.timeHHmmss(viewModel.tot)
                    )
                    
                }
                
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if viewModel.missionType == .hackTime {
                        HStack {
                            Button {
                                viewModel.startHack()
                            } label: {
                                Text("Hack!").font(.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("hackButton")
                            Button {
                                viewModel.presentEditHackTime()
                            } label: {
                                Text("Edit Hack").font(.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("editHackButton")
                        }
                        .controlSize(.large)
                        .buttonStyle(.glass)
                    } else {
                        HStack {
                            Button {
                                viewModel.presentEditToT()
                            } label: {
                                Text("Edit TOT").font(.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("editTOTButton")
                        }
                        .controlSize(.large)
                        .buttonStyle(.glass)
                        
                    }
                    
                    Button(role: .destructive) {
                        showEndFlightConfirm = true
                    } label: {
                        Text("End Flight").font(.title)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("endFlightButton")
                    .accessibilityHint("Stops tracking and closes out the current mission.")
                }
                .padding(.horizontal, Design.Padding.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
            }
            .sheet(isPresented: $viewModel.isEditingToT, onDismiss: viewModel.cancelEditToT, content: {
                let _date: Binding<Date> = Binding {
                    $viewModel.tot.wrappedValue ?? Date()
                } set: { d in
                    $viewModel.tot.wrappedValue = d
                }
                
                VStack {
                    TOTTimePickerView(date: _date, hour: _date.hourComponent, minute: _date.minuteComponent, second: _date.secondComponent)
                    Button {
                        viewModel.cancelEditToT()
                    } label: {
                        Text("Done")
                            .font(.title)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, Design.Padding.horizontal)
                    .controlSize(.large)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("editTOTDoneButton")
                }
            })
            .sheet(isPresented: $viewModel.isEditingHackTime, content: {
                VStack {
                    HackTimePickerView(hackDurationSeconds: $viewModel.hackTime)
                    Button {
                        viewModel.cancelHackTimeEdit()
                    } label: {
                        Text("Done")
                            .font(.title)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, Design.Padding.horizontal)
                    .controlSize(.large)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("editHackDoneButton")
                }
            })
            .confirmationDialog(
                "End Flight?",
                isPresented: $showEndFlightConfirm,
                titleVisibility: .visible
            ) {
                Button("End Flight", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will stop tracking and close out the current mission.")
            }
        }
        .accessibilityIdentifier("flightViewRoot")
        // Keep the screen awake for the duration of the flight. Pilots need the
        // timing and instrument readouts visible without touching the device, so
        // the system idle timer must not dim or lock the display while this view
        // is on screen. Re-enabled on disappear so the rest of the app behaves normally.
        //
        // The view model's live updates (location delegate, GPS, 1 Hz timer) are
        // bracketed by the same appear/disappear pair so End Flight actually stops
        // tracking and releases the view model.
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            viewModel.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.stop()
        }
    }
}

// coverage:ignore-start
@MainActor private func makeHackMissionGoodVM() -> FlightViewModel {
    let vm = FlightViewModel(
        missionName: "Training Hack",
        target: CLLocationCoordinate2D(latitude: 34.2000, longitude: -118.3500),
        missionType: .hackTime,
        settings: Settings(speedUnit: .mph, distanceUnit: .mi, yellowTolerance: 80, redTolerance: 100, instrumentSettings: [])
    )
    vm.currentTime = Date()
    vm.hackTime = 90 // 1m30s
    vm.ete = 85
    vm.eta = Calendar.current.date(byAdding: .second, value: 85, to: Date())
    vm.delta = -5
    vm.tot = Calendar.current.date(byAdding: .minute, value: 5, to: Date())
    vm.currentGroundSpeed = Measurement(value: 120, unit: UnitSpeed.knots)
    vm.requiredGroundSpeed = Measurement(value: 118, unit: UnitSpeed.knots)
    vm.distance = Measurement(value: 12.5, unit: UnitLength.nauticalMiles)
    vm.bearing = Measurement(value: 45, unit: UnitAngle.degrees)
    vm.track = Measurement(value: 44, unit: UnitAngle.degrees)
    vm.statusColor = .good
    return vm
}

@MainActor private func makeTOTBadVM() -> FlightViewModel {
    let vm = FlightViewModel(
        missionName: "Night Sortie",
        target: CLLocationCoordinate2D(latitude: 36.0800, longitude: -115.1522),
        missionType: .tot,
        settings: Settings(speedUnit: .kph, distanceUnit: .km, yellowTolerance: 20, redTolerance: 600, instrumentSettings: [])
    )
    vm.currentTime = Date()
    vm.ete = 600
    vm.eta = Calendar.current.date(byAdding: .minute, value: 10, to: Date())
    vm.delta = 120 // 2 minutes late
    vm.tot = Calendar.current.date(byAdding: .minute, value: 8, to: Date())
    vm.currentGroundSpeed = Measurement(value: 310, unit: UnitSpeed.knots)
    vm.requiredGroundSpeed = Measurement(value: 340, unit: UnitSpeed.knots)
    vm.distance = Measurement(value: 60, unit: UnitLength.nauticalMiles)
    vm.bearing = Measurement(value: 270, unit: UnitAngle.degrees)
    vm.track = Measurement(value: 260, unit: UnitAngle.degrees)
    vm.statusColor = .bad
    return vm
}

@MainActor private func makeInstrumentsReallyBadVM() -> FlightViewModel {
    let vm = FlightViewModel(
        missionName: "High Winds",
        target: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        missionType: .tot,
        settings: Settings(speedUnit: .kph, distanceUnit: .km, yellowTolerance: 80, redTolerance: 100, instrumentSettings: [])
    )
    vm.currentTime = Date()
    vm.ete = 300
    vm.eta = Calendar.current.date(byAdding: .minute, value: 5, to: Date())
    vm.delta = 240 // very late
    vm.tot = Calendar.current.date(byAdding: .minute, value: 1, to: Date())
    vm.currentGroundSpeed = Measurement(value: 90, unit: UnitSpeed.knots)
    vm.requiredGroundSpeed = Measurement(value: 140, unit: UnitSpeed.knots)
    vm.distance = Measurement(value: 10, unit: UnitLength.nauticalMiles)
    vm.bearing = Measurement(value: 200, unit: UnitAngle.degrees)
    vm.track = Measurement(value: 150, unit: UnitAngle.degrees)
    vm.statusColor = .reallyBad
    return vm
}

#Preview("Hack Mission - Good Status") {
    FlightView(viewModel: makeHackMissionGoodVM())
}

#Preview("TOT Mission - Bad Status") {
    FlightView(viewModel: makeTOTBadVM())
}

#Preview("Instruments - Really Bad Status") {
    FlightView(viewModel: makeInstrumentsReallyBadVM())
}
// coverage:ignore-end
