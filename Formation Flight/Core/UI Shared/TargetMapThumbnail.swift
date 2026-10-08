//
//  TargetMapThumbnail.swift
//  Formation Flight
//
//  D-08: a small static map of the target for the editor's Target row.
//

import SwiftUI
import MapKit

/// Static snapshot of the map around `coordinate` with a pin at the centre.
///
/// A live `Map` at thumbnail size is mostly covered by its "Legal" attribution and POI labels.
/// A snapshot has neither, and the full interactive map, with attribution, is one tap away in
/// the target picker. Re-renders when the coordinate, size or appearance changes.
struct TargetMapThumbnail: View {
    let coordinate: CLLocationCoordinate2D

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    /// Same framing the live thumbnail used: about 1 km across.
    private static let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
                Image(systemName: "mappin")
                    .font(.body)
                    .foregroundStyle(.red)
                    // The pin's tip, not its centre, marks the target.
                    .offset(y: -8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: RenderKey(latitude: coordinate.latitude, longitude: coordinate.longitude,
                                size: proxy.size, isDark: colorScheme == .dark)) {
                await render(size: proxy.size)
            }
        }
    }

    /// `CLLocationCoordinate2D` is not `Equatable`, so the task is keyed on this snapshot.
    private struct RenderKey: Equatable {
        let latitude: Double
        let longitude: Double
        let size: CGSize
        let isDark: Bool
    }

    private func render(size: CGSize) async {
        guard size.width > 0, size.height > 0 else { return }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, span: Self.span)
        options.size = size
        options.scale = displayScale
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        do {
            let snapshot = try await MKMapSnapshotter(options: options).start()
            image = snapshot.image
        } catch {
            // Keep the placeholder; the coordinate text beside the thumbnail is what matters.
            AppLogger.ui.debug("Target thumbnail snapshot failed: \(error.localizedDescription)")
        }
    }
}
