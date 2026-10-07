//
//  SafetyDisclaimerView.swift
//  Formation Flight
//
//  Aviation safety disclaimer sheet (R-07).
//

import SwiftUI

/// Scrollable safety disclaimer with a single acknowledgement button.
///
/// Presented as a non-dismissible full-screen cover on first launch and as a
/// regular sheet from Settings. The view itself does not record the
/// acknowledgement; the presenter decides what `onAcknowledge` means.
struct SafetyDisclaimerView: View {
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    Text(SafetyDisclaimer.title)
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("safetyDisclaimerTitle")

                    ForEach(Array(SafetyDisclaimer.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 16)
            }

            Button(action: onAcknowledge) {
                Text(SafetyDisclaimer.acknowledgeButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("safetyDisclaimerAcknowledgeButton")
        }
        .background(Color(.systemBackground))
        // A plain VStack is not an accessibility element, so its identifier is
        // invisible to UI tests unless it is made a container.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("safetyDisclaimerView")
    }
}

#Preview {
    SafetyDisclaimerView(onAcknowledge: { })
}
