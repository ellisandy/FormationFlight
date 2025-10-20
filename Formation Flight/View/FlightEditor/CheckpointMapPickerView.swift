import SwiftUI
import MapKit
import CoreLocation

struct CheckpointMapPickerView: View {
    var onSave: (_ name: String, _ coordinate: CLLocationCoordinate2D) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var pinCoordinate: CLLocationCoordinate2D

    init(
        onSave: @escaping (_ name: String, _ coordinate: CLLocationCoordinate2D) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        let currentLocation = LocationProvider().location
        _pinCoordinate = State(initialValue: currentLocation)
    }
    
    init(
        name: String,
        pinCoordinate: CLLocationCoordinate2D,
        onSave: @escaping (_ name: String, _ coordinate: CLLocationCoordinate2D) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: name)
        _pinCoordinate = State(initialValue: pinCoordinate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    Map(initialPosition: .region(MKCoordinateRegion(center: pinCoordinate,
                                                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))) {
                        Annotation("", coordinate: pinCoordinate, anchor: .bottom) {
                            Image(systemName: "mappin")
                                .font(.system(size: 42))
                                .foregroundStyle(.red)
                                .shadow(radius: 10)
                        }
                    }
                    .mapStyle(.hybrid)
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .continuous) { context in
                        pinCoordinate = context.region.center
                    }
                }
                .frame(minHeight: 300)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Checkpoint Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Latitude: \(pinCoordinate.latitude,format: .number.precision(.fractionLength(6)))")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, pinCoordinate)
                    }
                    .disabled(name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    CheckpointMapPickerView { _, _ in } onCancel: {}
}
