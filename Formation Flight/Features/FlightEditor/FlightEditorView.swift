import SwiftUI
import CoreLocation
import MapKit

@MainActor
struct FlightEditorView: View {
    @StateObject private var viewModel = FlightEditorViewModel()
    var onSave: (FlightEditorViewModel) -> Void = { _ in }
    var onCancel: () -> Void = {}
    
    init(flight: Flight? = nil, onSave: @escaping (FlightEditorViewModel) -> Void = { _ in }, onCancel: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: FlightEditorViewModel(flight: flight))
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("Mission Name") {
                    TextField("Mission Name", text: $viewModel.missionName)
                        .accessibilityIdentifier("missionNameField")
                }
                Section("Time Type") {
                    Picker("Time Type", selection: Binding(
                        get: { viewModel.useTOT ? 0 : 1 },
                        set: { newValue in viewModel.useTOT = (newValue == 0) }
                    )) {
                        Text("TOT").tag(0)
                        Text("Hack").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("timeTypeSegmentedControl")
                }
                Section("Time Entry") {
                    if viewModel.useTOT {
                        TOTTimePickerView(date: $viewModel.timeEntry,
                                          hour: $viewModel.hourComponent,
                                          minute: $viewModel.minuteComponent,
                                          second: $viewModel.secondComponent)
                    } else {
                        HackTimePickerView(
                            hackDurationSeconds: Binding<TimeInterval?>(
                                get: { TimeInterval(viewModel.hackDurationSeconds) },
                                set: { newValue in
                                    viewModel.hackDurationSeconds = Int(newValue ?? 0)
                                }
                            )
                        )
                    }
                }
                Section("Target") {
                    NavigationLink {
                        var location: CLLocationCoordinate2D {
                            viewModel.selectedTargetLocation ??
                            viewModel.currentLocation ??
                            CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
                        }
                        
                        CheckpointMapPickerView(
                            pinCoordinate: location,
                            onSave: { coordinate in
                                viewModel.applyTargetSelection(coordinate: coordinate)
                            },
                            onCancel: { }
                        )
                    } label: {
                        HStack(spacing: 8) {
                            // Left: coordinate description or placeholder, expands to fill remaining space
                            Group {
                                if let coord = viewModel.selectedTargetLocation {
                                    VStack(alignment: .leading) {
                                        Text("Lat: \(coord.latitude, format: .number.precision(.fractionLength(4)))")
                                            .accessibilityIdentifier("targetLatitudeLabel")
                                        Text("Lon: \(coord.longitude, format: .number.precision(.fractionLength(4)))")
                                            .accessibilityIdentifier("targetLongitudeLabel")
                                    }
                                } else {
                                    Text("Select Target")
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("SelectNewTargetLabel")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Right: Thumbnail map if we have a coordinate (fixed size)
                            if let coord = viewModel.selectedTargetLocation {
                                Map(initialPosition: .region(MKCoordinateRegion(center: coord,
                                                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                                    Annotation("", coordinate: coord, anchor: .bottom) {
                                        Image(systemName: "mappin")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.red)
                                    }
                                }
                                .accessibilityIdentifier("targetMapThumbnail")
                                .mapStyle(.standard)
                                .frame(width: 80, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("targetRow")

                }
                Section {
                    Button {
                        // TODO: Run validation before. Also, maybe save...?
                        
                        viewModel.presentFlightView()
                    } label: {
                        Text("Go Fly")
                            .font(.title)
                            .tint(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("goFlyButton")
                    .padding(.horizontal, 8)
                    .buttonStyle(.glass)
                }
                
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.isEditing ? "Save" : "Add") {
                    onSave(viewModel)
                }
                .bold()
                .accessibilityIdentifier("flightEditorSaveButton")
            }
        }
        .fullScreenCover(isPresented: $viewModel.isFlightViewPresented,
                         onDismiss: {
            viewModel.dismissFlightView()
        },
                         content: {
            //            onSave(viewModel)
            if let _target = viewModel.selectedTargetLocation,
               let _missionType: MissionType = viewModel.useTOT ? .tot : .hackTime
            {
                FlightView(viewModel: FlightViewModel(missionName: viewModel.missionName,
                                                      target: _target,
                                                      missionType: _missionType,
                                                      missionDate: viewModel.timeEntry,
                                                      hackTime: Double(viewModel.hackDurationSeconds),
                                                      settings: Settings.load(from: UserDefaults.standard)
                                                     ))
            }
        })
        .navigationTitle("Flight Editor")
    }
}

struct SimpleFlightEditor_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FlightEditorView(
                flight: nil,
                onSave: { _ in },
                onCancel: {}
            )
        }
    }
}

