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
                                    // B-34: never feed a non-finite or absurd value into `Int(_:)`.
                                    viewModel.hackDurationSeconds = newValue
                                        .flatMap(FlightEditorViewModel.hackDurationSeconds(from:)) ?? 0
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
                            }
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
                                            .font(.body)
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
                        viewModel.presentFlightView()
                    } label: {
                        Text("Go Fly")
                            .font(.title)
                            .tint(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.canGoFly)
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
        .alert("Validation", isPresented: Binding(
            get: { viewModel.validationMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.validationMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.validationMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.isFlightViewPresented,
                         onDismiss: {
            viewModel.dismissFlightView()
        },
                         content: {
            let missionType: MissionType = viewModel.useTOT ? .tot : .hackTime
            if let target = viewModel.selectedTargetLocation {
                FlightView(viewModel: FlightViewModel(missionName: viewModel.missionName,
                                                      target: target,
                                                      missionType: missionType,
                                                      missionDate: viewModel.timeEntry,
                                                      hackTime: Double(viewModel.hackDurationSeconds),
                                                      settings: Settings.load(from: UserDefaults.standard)
                                                     ))
            } else {
                // Safety net: the cover must never be empty and undismissable.
                VStack(spacing: 16) {
                    Text(viewModel.goFlyValidationMessage
                         ?? String(localized: "Please enter a valid target location.",
                                   comment: "Validation message when a flight has no target selected"))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("flightViewFallbackMessage")
                    Button("Close") {
                        viewModel.dismissFlightView()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("flightViewFallbackCloseButton")
                }
                .padding()
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

