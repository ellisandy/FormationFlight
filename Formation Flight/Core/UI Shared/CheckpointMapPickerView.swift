import SwiftUI
import MapKit
import CoreLocation

struct CheckpointMapPickerView: View {
    var onSave: (_ coordinate: CLLocationCoordinate2D) -> Void
    var onCancel: () -> Void
    var locationProvider = CLLocationManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var pinCoordinate: CLLocationCoordinate2D
    
    init(
        pinCoordinate: CLLocationCoordinate2D,
        onSave: @escaping (_ coordinate: CLLocationCoordinate2D) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
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
                                                                    .accessibilityIdentifier("checkpointMap")
                                                                    .onMapCameraChange(frequency: .continuous) { context in
                                                                        pinCoordinate = context.region.center
                                                                    }
                }
                .frame(minHeight: 300)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Latitude", text: Binding(
                            get: { String(format: "%.6f", pinCoordinate.latitude) },
                            set: { newValue in
                                if let v = Double(newValue), v >= -90, v <= 90 {
                                    pinCoordinate.latitude = v
                                }
                            }
                        ))
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        
                        TextField("Longitude", text: Binding(
                            get: { String(format: "%.6f", pinCoordinate.longitude) },
                            set: { newValue in
                                if let v = Double(newValue), v >= -180, v <= 180 {
                                    pinCoordinate.longitude = v
                                }
                            }
                        ))
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                    }
                    
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(pinCoordinate)
                        dismiss()
                    }
                    .accessibilityIdentifier("checkpointSaveButton")
                }
            }
        }
    }
}
