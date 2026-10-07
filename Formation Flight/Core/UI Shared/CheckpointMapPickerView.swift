import SwiftUI
import MapKit
import CoreLocation

/// Parses a typed coordinate component (B-15).
enum CoordinateParsing {
    /// Parses `text` as a decimal degree value within `range`.
    ///
    /// Accepts a decimal point or a decimal comma and ignores surrounding whitespace, then
    /// falls back to the current locale's number formatter (grouping separators, non-Latin
    /// digits). Returns `nil` for anything non-numeric, non-finite, or outside `range`.
    static func parse(_ text: String, range: ClosedRange<Double>) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let value = Double(trimmed)
            ?? Double(trimmed.replacingOccurrences(of: ",", with: "."))
            ?? localeFormatter.number(from: trimmed)?.doubleValue

        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }

    private static let localeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

struct CheckpointMapPickerView: View {
    var onSave: (_ coordinate: CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss

    static let latitudeRange: ClosedRange<Double> = -90...90
    static let longitudeRange: ClosedRange<Double> = -180...180
    private static let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    /// Camera settles within floating-point noise of a programmatic recentre; anything closer
    /// than this (about a metre) is not treated as the user having moved the map.
    private static let sameCoordinateTolerance = 1e-5

    @State private var pinCoordinate: CLLocationCoordinate2D
    // B-15: the camera is view state so a typed coordinate can recentre the map.
    @State private var cameraPosition: MapCameraPosition
    // B-15: the fields hold plain text while the user types; the coordinate is parsed on
    // submit. Re-formatting on every keystroke used to snap intermediate input back.
    @State private var latitudeText: String
    @State private var longitudeText: String

    private enum Field: Hashable {
        case latitude
        case longitude
    }
    @FocusState private var focusedField: Field?

    init(
        pinCoordinate: CLLocationCoordinate2D,
        onSave: @escaping (_ coordinate: CLLocationCoordinate2D) -> Void
    ) {
        self.onSave = onSave
        _pinCoordinate = State(initialValue: pinCoordinate)
        _cameraPosition = State(initialValue: Self.position(centredOn: pinCoordinate))
        _latitudeText = State(initialValue: Self.format(pinCoordinate.latitude))
        _longitudeText = State(initialValue: Self.format(pinCoordinate.longitude))
    }

    // B-20: no inner NavigationStack; this view is pushed by the editor's stack, so the
    // title and toolbar attach to the content directly.
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Map(position: $cameraPosition)
                    .mapStyle(.hybrid)
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityIdentifier("checkpointMap")
                    // B-15: follow the camera only once a drag ends, so a typed value is not
                    // overwritten by the continuous stream of camera updates.
                    .onMapCameraChange(frequency: .onEnd) { context in
                        cameraDidSettle(at: context.region.center)
                    }

                // The pin is drawn over the map's centre so it tracks a drag smoothly; the
                // coordinate under it is read when the gesture ends.
                Image(systemName: "mappin")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(.red)
                    .shadow(radius: 10)
                    .alignmentGuide(VerticalAlignment.center) { $0[.bottom] }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 300)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .latitude)
                        .submitLabel(.done)
                        .onSubmit { commitTypedCoordinate() }
                        .accessibilityIdentifier("latitudeField")

                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .longitude)
                        .submitLabel(.done)
                        .onSubmit { commitTypedCoordinate() }
                        .accessibilityIdentifier("longitudeField")
                }

                HStack {
                    Text("Latitude: \(pinCoordinate.latitude, format: .number.precision(.fractionLength(6)))")
                    Spacer()
                    Text("Longitude: \(pinCoordinate.longitude, format: .number.precision(.fractionLength(6)))")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("Pick Checkpoint")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // A value still sitting in a field counts; the pilot typed it to use it.
                    commitTypedCoordinate()
                    onSave(pinCoordinate)
                    dismiss()
                }
                .accessibilityIdentifier("checkpointSaveButton")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    commitTypedCoordinate()
                    focusedField = nil
                }
                .accessibilityIdentifier("coordinateDoneButton")
            }
        }
    }

    // MARK: - Coordinate plumbing

    /// Parses both fields; a field that does not parse keeps the pin's current value. If the
    /// result differs from the pin, the pin moves and the camera recentres on it. Both fields
    /// are then re-formatted so invalid or oddly spaced input reads back as the value in use.
    private func commitTypedCoordinate() {
        let latitude = CoordinateParsing.parse(latitudeText, range: Self.latitudeRange) ?? pinCoordinate.latitude
        let longitude = CoordinateParsing.parse(longitudeText, range: Self.longitudeRange) ?? pinCoordinate.longitude
        let typed = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        if !Self.isSame(typed, pinCoordinate) {
            pinCoordinate = typed
            cameraPosition = Self.position(centredOn: typed)
        }
        syncText(from: pinCoordinate)
    }

    /// Called when a camera movement ends. A programmatic recentre settles on the typed
    /// coordinate (within noise) and is ignored; a user drag moves the pin and the text.
    private func cameraDidSettle(at center: CLLocationCoordinate2D) {
        guard !Self.isSame(center, pinCoordinate) else { return }
        pinCoordinate = center
        syncText(from: center)
    }

    /// Writes the coordinate into the text fields, leaving a field the user is editing alone.
    private func syncText(from coordinate: CLLocationCoordinate2D) {
        if focusedField != .latitude {
            latitudeText = Self.format(coordinate.latitude)
        }
        if focusedField != .longitude {
            longitudeText = Self.format(coordinate.longitude)
        }
    }

    private static func position(centredOn coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: coordinate, span: span))
    }

    private static func format(_ degrees: Double) -> String {
        degrees.formatted(.number.precision(.fractionLength(6)).grouping(.never))
    }

    private static func isSame(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < sameCoordinateTolerance
            && abs(a.longitude - b.longitude) < sameCoordinateTolerance
    }
}

#Preview {
    NavigationStack {
        CheckpointMapPickerView(pinCoordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)) { _ in }
    }
}
