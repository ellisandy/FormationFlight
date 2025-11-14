//
//  FlightEditorForm.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/24/23.
//

import SwiftUI
import Combine
import MapKit

struct FlightEditorForm: View {
    @Binding var config: FlightEditorConfig
    @State var checkPointPopover = false
    @State var isFlightViewPresented = false
    @State var editingCheckpointIndex: Int? = nil
    @State private var settingsConfig = SettingsEditorConfig.from(userDefaults: UserDefaults.standard)

    
    var body: some View {
        NavigationStack {
            Form{
                Section(header: Text("Flight Overview")) {
                    TextField("Mission Title", text: $config.flight.title)
                        .accessibilityIdentifier("missionTitleField")
                    DatePicker("Mission Date", selection: $config.flight.missionDate, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("missionDatePicker")

                    // Mark Time Input (used to reset ToT by pressing Mark)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enroute Time (mm:ss)")
                            .font(.headline)

                        HStack(alignment: .center) {
                            // Minutes wheel
                            Picker("Minutes", selection: Binding<Int>(
                                get: {
                                    let total = Int(config.flight.markTimeInSeconds ?? 0)
                                    return max(0, total / 60)
                                },
                                set: { (newMinutes: Int) in
                                    let total = Int(config.flight.markTimeInSeconds ?? 0)
                                    let seconds = max(0, total % 60)
                                    let newTotal = max(0, newMinutes) * 60 + seconds
                                    config.flight.markTimeInSeconds = Double(newTotal)
                                }
                            )) {
                                ForEach(0..<60, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .clipped()
                            .accessibilityIdentifier("markTimeMinutesPicker")

                            Text(":")
                                .font(.title2)
                                .monospacedDigit()

                            // Seconds wheel
                            Picker("Seconds", selection: Binding<Int>(
                                get: {
                                    let total = Int(config.flight.markTimeInSeconds ?? 0)
                                    return max(0, total % 60)
                                },
                                set: { (newSeconds: Int) in
                                    let total = Int(config.flight.markTimeInSeconds ?? 0)
                                    let minutes = max(0, total / 60)
                                    let clamped = min(max(0, newSeconds), 59)
                                    let newTotal = minutes * 60 + clamped
                                    config.flight.markTimeInSeconds = Double(newTotal)
                                }
                            )) {
                                ForEach(0..<60, id: \.self) { s in
                                    Text(String(format: "%02d", s)).tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .accessibilityIdentifier("markTimeSecondsPicker")
                        }
                    }
                }
                Section("Wind Conditions") {
                    HStack {
                        Text("Estimated Direction:")
                        TextField("Wind Direction", text: $config.flight.expectedWinds.windDirectionAsText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("windDirectionField")
                    }

                    HStack {
                        Text("Estimated Velocity:  ")
                        TextField("Wind Velocity", text: $config.flight.expectedWinds.windVelocityAsText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("windVelocityField")
                        Spacer()
                        Text(String(describing: $settingsConfig.speedUnit.wrappedValue))
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Flight Plan") {
                    ForEach(Array(config.flight.checkPoints.enumerated()), id: \.element.id) { index, checkPoint in
                        Button {
                            editingCheckpointIndex = index
                            checkPointPopover = true
                        } label: {
                            HStack {
                                Text(checkPoint.name)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(checkPoint.longitude)")
                                    Text("\(checkPoint.latitude)")
                                }
                            }
                        }
                        .accessibilityIdentifier("checkpointRow_\(index)")
                    }
                    .onDelete(perform: { indexSet in
                        config.flight.checkPoints.remove(atOffsets: indexSet)
                    })
                    .onMove(perform: { indices, newOffset in
                        config.flight.checkPoints.move(fromOffsets: indices, toOffset: newOffset)
                    })
                    Button("New Check Point") {
                        editingCheckpointIndex = nil
                        checkPointPopover = true
                    }
                    .accessibilityIdentifier("newCheckpointButton")
                    .sheet(isPresented: $checkPointPopover) {
                        if let cpIndex = editingCheckpointIndex {
                            let currentName: String = config.flight.checkPoints[cpIndex].name
                            let currentCoordinate: CLLocationCoordinate2D = config.flight.checkPoints[cpIndex].getCLCoordinate()
                            
                            CheckpointMapPickerView(name: currentName,
                                                    pinCoordinate: currentCoordinate,
                                                    onSave: { name, coordinate in
                                config.flight.checkPoints[cpIndex].name = name
                                config.flight.checkPoints[cpIndex].longitude = coordinate.longitude
                                config.flight.checkPoints[cpIndex].latitude = coordinate.latitude
                                dismissCheckpointSheet()
                            },
                                                    onCancel: {
                                dismissCheckpointSheet()
                            })
                            .accessibilityIdentifier("checkpointSheet")
                        } else {
                            let location = CLLocationManager().location ?? CLLocation(latitude: 0, longitude: 0)
                            
                            CheckpointMapPickerView(name: "",
                                                    pinCoordinate: location.coordinate,
                                                    onSave: { name, coordinate in
                                let cp = CheckPoint(name: name,
                                                    location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                                config.flight.checkPoints.append(cp)
                                dismissCheckpointSheet()
                            },
                                                    onCancel: {
                                dismissCheckpointSheet()
                            })
                            .accessibilityIdentifier("checkpointSheet")
                        }
                    }
                }
            }
            Button {
                config.flight.inflightCheckPoints = config.flight.checkPoints
                
                // Start Flight
                isFlightViewPresented.toggle()
            } label: {
                Text("Start Flight")
                    .font(.title)
                    .buttonStyle(.glassProminent)
            }
            .fullScreenCover(isPresented: $isFlightViewPresented) {
                ZStack {
                    flightContentView(for: config.flight)
                    SlidingSheetView() {
                        instrumentPanelView()
                    }.ignoresSafeArea(edges: .all)
                }
            }
        }
    }
 
    let windInputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = false
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    func dismissCheckpointSheet() {
        checkPointPopover = false
        editingCheckpointIndex = nil
    }

    
    @ViewBuilder
    private func flightContentView(for flight: Flight) -> some View {
        FlightView(
            flight: flight,
            settingsConfig: $settingsConfig,
            isFlightViewPresented: $isFlightViewPresented
        )
    }

    @ViewBuilder
    private func instrumentPanelView() -> some View {
        InstrumentPanel(
            isFlightViewPresented: $isFlightViewPresented,
            settingsConfig: $settingsConfig,
            flight: $config.flight
        )
    }
}

#Preview {
    FlightEditorForm(config: .constant(FlightEditorConfig()))
}

