//
//  FlightViewV2.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/12/25.
//

import SwiftUI
import CoreLocation

private struct LabelValueRow: View {
    let label: String
    let value: String?
    var valueColor: Color? = nil
    
    var body: some View {
        HStack {
            Text(label).font(.title)
            Spacer()
            Text(value ?? "")
                .font(.title)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
        .padding(.horizontal, Design.Padding.horizontal)
        .accessibilityElement(children: .combine)
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
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(titleFont)
            Text(value ?? "---")
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .cardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "---")
    }
}

// MARK: - Date Component Accessors
private extension Date {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }
    
    var hourSetter: Int {
        get { calendar.component(.hour, from: self) }
        set {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: self)
            var newComps = comps
            newComps.hour = newValue
            if let newDate = calendar.date(from: newComps) {
                self = newDate
            }
        }
    }
    
    var minuteSetter: Int {
        get { calendar.component(.minute, from: self) }
        set {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: self)
            var newComps = comps
            newComps.minute = newValue
            if let newDate = calendar.date(from: newComps) {
                self = newDate
            }
        }
    }
    
    var secondSetter: Int {
        get { calendar.component(.second, from: self) }
        set {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: self)
            var newComps = comps
            newComps.second = newValue
            if let newDate = calendar.date(from: newComps) {
                self = newDate
            }
        }
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
            LabelValueRow(label: "Time", value: time)
                .padding(.top, 10)
            
            LabelValueRow(label: "ETE", value: ete)
            LabelValueRow(label: "ETA", value: eta, valueColor: emphasisColor)
            LabelValueRow(label: "Δ", value: delta, valueColor: emphasisColor)
            LabelValueRow(label: "TOT", value: tot)
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
                InstrumentCard(title: "Cur GS", value: curGS, valueColor: emphasisColor)
                InstrumentCard(title: "Req GS", value: reqGS, valueColor: emphasisColor)
                InstrumentCard(title: "Dist", value: dist)
            }
            .padding(.horizontal, Design.Padding.horizontal)
            .padding(.vertical, 5)
            
            HStack(spacing: 5) {
                InstrumentCard(title: "Brg", value: curBrg, verticalPadding: 5, titleFont: .title2, valueFont: .title)
                InstrumentCard(title: "Trk", value: curTrk, verticalPadding: 5, titleFont: .title2, valueFont: .title)
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
    
    init(viewModel: FlightViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                        delta: Formatting.durationHMS(viewModel.delta),
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
                            Button {
                                viewModel.presentEditHackTime()
                            } label: {
                                Text("Edit Hack").font(.title)
                                    .frame(maxWidth: .infinity)
                            }
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
                    TOTTimePickerView(date: _date, hour: _date.hourSetter, minute: _date.minuteSetter, second: _date.secondSetter)
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
