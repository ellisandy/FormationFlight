import SwiftUI
import CoreLocation
import MapKit

@MainActor
struct FlightEditorView: View {
    @StateObject private var viewModel = FlightEditorViewModel()
    var onSave: (FlightEditorViewModel) -> Void = { _ in }
    var onCancel: () -> Void = {}

    // B-33: the thumbnail camera is view state so it can follow a changed target.
    @State private var thumbnailPosition: MapCameraPosition
    // B-21: Cancel on a dirty editor asks before discarding.
    @State private var showsDiscardConfirmation = false

    init(flight: Flight? = nil, onSave: @escaping (FlightEditorViewModel) -> Void = { _ in }, onCancel: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: FlightEditorViewModel(flight: flight))
        _thumbnailPosition = State(initialValue: Self.thumbnailPosition(for: flight?.target?.getCLCoordinate()))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// `CLLocationCoordinate2D` is not `Equatable`, so `onChange` observes this snapshot instead.
    private struct CoordinateKey: Equatable {
        let latitude: Double
        let longitude: Double
    }

    private var selectedTargetKey: CoordinateKey? {
        viewModel.selectedTargetLocation.map {
            CoordinateKey(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private static func thumbnailPosition(for coordinate: CLLocationCoordinate2D?) -> MapCameraPosition {
        guard let coordinate else { return .automatic }
        return .region(MKCoordinateRegion(center: coordinate,
                                          span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
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
                                Map(position: $thumbnailPosition) {
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
            // B-37: single request per appearance; `.onAppear` used to fire a duplicate.
            viewModel.requestLocationIfNeeded()
        }
        .onChange(of: selectedTargetKey) { _, _ in
            thumbnailPosition = Self.thumbnailPosition(for: viewModel.selectedTargetLocation)
        }
        .toolbar {
            // B-21: Cancel is the single way out; the system back button is hidden below so
            // edits can never be dropped silently.
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if viewModel.isDirty {
                        showsDiscardConfirmation = true
                    } else {
                        onCancel()
                    }
                }
                .accessibilityIdentifier("flightEditorCancelButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.isEditing ? "Save" : "Add") {
                    onSave(viewModel)
                }
                .bold()
                .accessibilityIdentifier("flightEditorSaveButton")
            }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("Discard changes?",
                            isPresented: $showsDiscardConfirmation,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                onCancel()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Your changes to this flight will not be saved.")
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
                    Text(viewModel.goFlyValidationMessage ?? FlightValidation.missingTargetMessage)
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

