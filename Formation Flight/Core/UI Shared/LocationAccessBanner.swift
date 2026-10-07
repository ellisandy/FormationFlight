//
//  LocationAccessBanner.swift
//  Formation Flight
//
//  Location permission banner with a route to Settings (B-16).
//

import SwiftUI
import UIKit

/// Tells the user that location is off or imprecise and offers to open Settings.
///
/// Renders nothing for `.authorized` and `.notDetermined`: the former needs no banner and
/// the latter is still waiting on the system prompt. The presenter decides where the card
/// sits; the card only owns its own colours and padding.
struct LocationAccessBanner: View {
    let access: LocationAccess

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch access {
        case .authorized, .notDetermined:
            EmptyView()
        case .denied:
            card(systemImage: "location.slash.fill",
                 title: Text("Location access is off"),
                 message: Text("Formation Flight needs your location to show distance, bearing, and groundspeed in flight."))
        case .reducedAccuracy:
            card(systemImage: "location.circle",
                 title: Text("Precise location is off"),
                 message: Text("Turn on Precise Location in Settings for accurate distance and timing."))
        }
    }

    private func card(systemImage: String, title: Text, message: Text) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    title
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    message
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .accessibilityIdentifier("locationAccessOpenSettingsButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35))
        )
        // A plain VStack is not an accessibility element, so its identifier is invisible to
        // UI tests unless it is made a container.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locationAccessBanner")
    }
}

#Preview("Denied") {
    LocationAccessBanner(access: .denied)
        .padding()
}

#Preview("Reduced accuracy") {
    LocationAccessBanner(access: .reducedAccuracy)
        .padding()
}

#Preview("Authorized (renders nothing)") {
    LocationAccessBanner(access: .authorized)
        .padding()
}

#Preview("Not determined (renders nothing)") {
    LocationAccessBanner(access: .notDetermined)
        .padding()
}
