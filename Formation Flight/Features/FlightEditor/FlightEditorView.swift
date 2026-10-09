import SwiftUI
import CoreLocation
import MapKit
import FormationFlightCore

@MainActor
struct FlightEditorView: View {
    @StateObject private var viewModel = FlightEditorViewModel()
    var onSave: (FlightEditorViewModel) -> Void = { _ in }
    var onCancel: () -> Void = {}

    // B-21: Cancel on a dirty editor asks before discarding.
    @State private var showsDiscardConfirmation = false
    // B-16: the user may return from Settings after changing the location permission.
    @Environment(\.scenePhase) private var scenePhase

    /// Where the map picker opens when neither a target nor a device fix is known (B-16).
    ///
    /// Apple Park, Cupertino. Deliberate: there is no better default for an unknown user, and
    /// the picker's purpose is to let them move the pin anyway. The banner above the form
    /// explains why their own location is missing when access is denied or imprecise.
    static let fallbackPickerCoordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    init(flight: Flight? = nil,
         locationProvider: LocationProviding = LocationProvider.shared,
         onSave: @escaping (FlightEditorViewModel) -> Void = { _ in },
         onCancel: @escaping () -> Void = {}) {
        let provider = UITestLocationAccessOverride.provider ?? locationProvider
        _viewModel = StateObject(wrappedValue: FlightEditorViewModel(flight: flight, locationProvider: provider))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 16) {
            Form {
                // B-16: only denied and reduced-accuracy states have anything to say; the
                // banner itself renders nothing otherwise, but omitting the Section avoids an
                // empty row.
                if viewModel.locationAccess == .denied || viewModel.locationAccess == .reducedAccuracy {
                    Section {
                        LocationAccessBanner(access: viewModel.locationAccess)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
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
                            Self.fallbackPickerCoordinate
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
                                // D-08: a static snapshot. A live `Map` this small was mostly
                                // covered by its "Legal" link and POI labels. B-33: it re-renders
                                // whenever the target moves.
                                TargetMapThumbnail(coordinate: coord)
                                    .frame(width: 80, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityIdentifier("targetMapThumbnail")
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
            .readableScrollContent()
            
            
        }
        .task {
            // B-37: single request per appearance; `.onAppear` used to fire a duplicate.
            viewModel.requestLocationIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            // B-16: coming back from Settings re-activates the scene; pick up the new status.
            if phase == .active {
                viewModel.refreshLocationAccess()
            }
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
        // An alert rather than a confirmation dialog: anchored to a toolbar button the
        // dialog becomes a popover, and popover action sheets drop their cancel-role
        // button entirely, so "Keep Editing" would never be shown.
        .alert("Discard changes?", isPresented: $showsDiscardConfirmation) {
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
                                                      settings: Settings.load(from: UserDefaults.standard),
                                                      speaker: SystemCalloutSpeaker(),
                                                      mirrors: FlightMirrors.makeDefault()
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

// MARK: - UI test support

// coverage:ignore-start
/// Lets a UI test force the editor into the denied-location state (B-16).
///
/// The simulator grants location through the tests' interruption monitor, so the banner can
/// never be reached through real Core Location. Launching with `-uiTestsLocationDenied`
/// substitutes a fixed provider for the shared one; in every other launch `provider` is `nil`
/// and the editor uses whatever it was given.
@MainActor
enum UITestLocationAccessOverride {
    static let launchArgument = "-uiTestsLocationDenied"

    static var provider: LocationProviding? {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return nil }
        return DeniedLocationProvider()
    }

    /// A provider that reports `.denied` and never produces a fix.
    private final class DeniedLocationProvider: LocationProviding {
        var updateDelegate: (() -> Void)?
        let authorizationStatus: CLAuthorizationStatus = .denied
        let accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
        @available(*, deprecated, renamed: "authorizationStatus")
        var authroizationStatus: CLAuthorizationStatus? { authorizationStatus }
        let speed = Measurement(value: -1, unit: UnitSpeed.metersPerSecond)
        let altitude = Measurement(value: -1, unit: UnitLength.meters)
        let course = Measurement(value: -1, unit: UnitAngle.degrees)
        let currentLocation: CLLocation? = nil
        let computedSpeedAndCourse = false
        let lastFixTimestamp: Date? = nil

        func startMonitoring() {}
        func stopMonitoring() {}
        func requestWhenInUseAuthorization() {}
    }
}
// coverage:ignore-end

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

