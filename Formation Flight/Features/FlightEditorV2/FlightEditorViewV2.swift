import SwiftUI
import CoreLocation
import MapKit

@MainActor
struct FlightEditorViewV2: View {
    @StateObject private var viewModel = FlightEditorViewModel()
    @State private var showingMapPicker: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Target")) {
                TextField("Title", text: $viewModel.flightTitle)
            }
            
            Section(header: Text("Time Type")) {
                Picker("Time Type", selection: Binding(
                    get: { viewModel.useTOT ? 0 : 1 },
                    set: { newValue in viewModel.useTOT = (newValue == 0) }
                )) {
                    Text("TOT").tag(0)
                    Text("Hack").tag(1)
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Time Entry")) {
                if viewModel.useTOT {
                    // TOT: custom wheels for hour, minute, second (same date retained)
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("Date", selection: $viewModel.timeEntry, displayedComponents: [.date])
                            .datePickerStyle(.compact)

                        HStack {
                            // Hour wheel 0-23
                            Picker("Hour", selection: $viewModel.hourComponent) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            // Minute wheel 0-59
                            Picker("Minute", selection: $viewModel.minuteComponent) {
                                ForEach(0..<60, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            // Second wheel 0-59
                            Picker("Second", selection: $viewModel.secondComponent) {
                                ForEach(0..<60, id: \.self) { s in
                                    Text(String(format: "%02d", s)).tag(s)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 140)
                        .scaleEffect(0.8)
                        .clipped()
                        .accessibilityElement(children: .contain)
                    }
                } else {
                    // Hack: minutes and seconds duration
                    HStack {
                        Picker("Min", selection: Binding(
                            get: { viewModel.hackDurationSeconds / 60 },
                            set: { newMin in viewModel.hackDurationSeconds = newMin * 60 + (viewModel.hackDurationSeconds % 60) }
                        )) {
                            ForEach(0..<181, id: \.self) { m in
                                Text("\(m)m").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Sec", selection: Binding(
                            get: { viewModel.hackDurationSeconds % 60 },
                            set: { newSec in viewModel.hackDurationSeconds = (viewModel.hackDurationSeconds / 60) * 60 + newSec }
                        )) {
                            ForEach(0..<60, id: \.self) { s in
                                Text(String(format: "%02ds", s)).tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 140)
                    .scaleEffect(0.8)
                    .clipped()
                    .accessibilityElement(children: .contain)
                }
            }
            
            Section(header: Text("Expected Winds")) {
                HStack {
                    TextField("Dir (°)", text: $viewModel.windDirection)
                        .keyboardType(.numberPad)
                    Divider()
                    TextField("Spd (kt)", text: $viewModel.windSpeed)
                        .keyboardType(.numberPad)
                }
                .accessibilityElement(children: .contain)
            }

            
            Section(header: Text("Checkpoint")) {
                Button {
                    showingMapPicker = true
                } label: {
                    HStack(spacing: 8) {
                        // Left: Name or placeholder, expands to fill remaining space
                        Group {
                            if let name = viewModel.selectedCoordinateDescription, !name.isEmpty {
                                Text(name)
                            } else if !viewModel.selectedCheckpoint.isEmpty {
                                Text(viewModel.selectedCheckpoint)
                            } else {
                                Text("Select Checkpoint")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Right: Thumbnail map if we have a coordinate (fixed size)
                        if let coord = viewModel.selectedCoordinate {
                            Map(initialPosition: .region(MKCoordinateRegion(center: coord,
                                                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                                Annotation("", coordinate: coord, anchor: .bottom) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.red)
                                }
                            }
                            .mapStyle(.standard)
                            .frame(width: 80, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                CheckpointMapPickerView(
                    name: viewModel.selectedCoordinateDescription ?? viewModel.selectedCheckpoint,
                    pinCoordinate: viewModel.currentCoordinate ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                    onSave: { name, coordinate in
                        viewModel.applyCheckpointSelection(name: name, coordinate: coordinate)
                        showingMapPicker = false
                    },
                    onCancel: {
                        showingMapPicker = false
                    }
                )
            }
        }
        .task {
            viewModel.requestLocationIfNeeded()
        }
        .onAppear {
            Task {
                viewModel.requestLocationIfNeeded()
            }
        }
        .navigationTitle("Flight Editor")
    }
}

struct SimpleFlightEditor_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FlightEditorViewV2()
        }
    }
}
