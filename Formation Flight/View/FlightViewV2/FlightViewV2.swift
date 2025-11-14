//
//  FlightViewV2.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/12/25.
//

import SwiftUI
import CoreLocation

// MARK: - Constants & Helpers

private let horizontalPadding: CGFloat = 8

private extension View {
    func cardBackground() -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct LabelValueRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(label).font(.title)
            Spacer()
            Text(value)
                .font(.title)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
        .padding(.horizontal, horizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct InstrumentCard: View {
    let title: String
    let value: String
    var valueColor: Color? = nil
    var verticalPadding: CGFloat = 10
    var titleFont: Font = .title2
    var valueFont: Font = .title

    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(titleFont)
            Text(value)
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .cardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

// MARK: - Coordinate Formatting
private func dmsString(from coordinate: CLLocationCoordinate2D) -> (lat: String, lon: String) {
    func format(value: Double, positiveHemisphere: String, negativeHemisphere: String) -> String {
        let hemisphere = value >= 0 ? positiveHemisphere : negativeHemisphere
        let absValue = abs(value)
        let degrees = Int(absValue)
        let minutesDecimal = (absValue - Double(degrees)) * 60
        // Keep two decimal places for minutes like the original strings
        let minutes = String(format: "%02.2f", minutesDecimal)
        return "\(hemisphere) \(degrees) \(minutes)"
    }
    let lat = format(value: coordinate.latitude, positiveHemisphere: "N", negativeHemisphere: "S")
    let lon = format(value: coordinate.longitude, positiveHemisphere: "E", negativeHemisphere: "W")
    return (lat, lon)
}

// MARK: - Time Formatting (24-hour)
private extension DateFormatter {
    static let hhmmssPOSIX: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "HH:mm:ss"
        return df
    }()
}

private func formatTimeHHmmss(_ date: Date) -> String {
    DateFormatter.hhmmssPOSIX.string(from: date)
}

private extension Duration {
    static let hmsPOSIXFormatter: Duration.TimeFormatStyle =
        .time(pattern: .hourMinuteSecond)
        .locale(Locale(identifier: "en_US_POSIX"))
}

private func formatDurationHMS(_ seconds: Double) -> String {
    let wholeSeconds = Int64(seconds)
    let nanos = Int64((seconds - Double(wholeSeconds)) * 1_000_000_000)
    let duration = Duration(secondsComponent: wholeSeconds, attosecondsComponent: nanos * 1_000_000_000)
    return duration.formatted(Duration.hmsPOSIXFormatter)
}

// MARK: - Main View

struct FlightViewV2: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var showEndFlightConfirm = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.cyan, Color.teal.opacity(0.78)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                
            ScrollView {
                VStack {
                    HStack {
                        Text("Timing").font(.largeTitle.bold())
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 10)

                    VStack {
                        LabelValueRow(label: "Time", value: formatTimeHHmmss(viewModel.currentTime))
                        LabelValueRow(label: "ETE", value: formatDurationHMS(viewModel.ete))
                        LabelValueRow(label: "ETA", value: formatTimeHHmmss(viewModel.eta), valueColor: .yellow)
                        LabelValueRow(label: "Δ", value: formatDurationHMS(viewModel.delta), valueColor: .green)
                        LabelValueRow(label: "TOT", value: formatTimeHHmmss(viewModel.tot))
                            .padding(.bottom, 10)
                    }

                    .cardBackground()
                    .padding(.horizontal, horizontalPadding)
                    
                    HStack {
                        Text("Instruments").font(.largeTitle.bold())
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 10)
                    
                    HStack(spacing: 5) {
                        InstrumentCard(title: "Cur GS", value: viewModel.currentGroundSpeed.formatted(.measurement(width: .abbreviated)))
                        InstrumentCard(title: "Req GS", value: viewModel.requiredGroundSpeed.formatted(.measurement(width: .abbreviated)), valueColor: .red)
                        InstrumentCard(title: "Dist", value: viewModel.distance.formatted(.measurement(width: .abbreviated)))
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 5)
                    
                    HStack(spacing: 5) {
                        InstrumentCard(title: "Brg", value: viewModel.bearing.formatted(.number.precision(.fractionLength(0))) + "°", verticalPadding: 5, titleFont: .title2, valueFont: .title)
                        InstrumentCard(title: "Trk", value: viewModel.track.formatted(.number.precision(.fractionLength(0))) + "°", verticalPadding: 5, titleFont: .title2, valueFont: .title)
                        InstrumentCard(
                            title: "Winds",
                            value: viewModel.windDirection.formatted(.number.precision(.fractionLength(0))) + "@" + viewModel.windSpeed.converted(to: .knots).value.formatted(.number.precision(.fractionLength(0))),
                            verticalPadding: 5,
                            titleFont: .title2,
                            valueFont: .title
                        )
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 5)
                    
                    Text("Mission Details").font(.largeTitle.bold())
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 5)

                    VStack {
                        LabelValueRow(label: "Target", value: viewModel.targetName)
                        let coordStrings = dmsString(from: viewModel.coordinate)
                        LabelValueRow(label: "Latitude", value: coordStrings.lat)
                        LabelValueRow(label: "Longitude", value: coordStrings.lon)
                        LabelValueRow(label: "TOT", value: formatTimeHHmmss(viewModel.tot))
                            .padding(.bottom, 10)
                    }
                    .cardBackground()
                    .padding(.horizontal, horizontalPadding)
                    
                    
                }
                
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack {
                        Button {
                            // TODO: Edit TOT action
                        } label: {
                            Text("Edit TOT").font(.title2)
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            // TODO: Adjust Winds action
                        } label: {
                            Text("Adjust Winds").font(.title2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.glass)

                    Button(role: .destructive) {
                        showEndFlightConfirm = true
                    } label: {
                        Text("End Flight").font(.title)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.glass)
                    .accessibilityHint("Stops tracking and closes out the current mission.")
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
                .background(.thinMaterial)
            }
            .confirmationDialog(
                "End Flight?",
                isPresented: $showEndFlightConfirm,
                titleVisibility: .visible
            ) {
                Button("End Flight", role: .destructive) {
                    // TODO: perform end flight action
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will stop tracking and close out the current mission.")
            }
        }
    }
}

#Preview {
    FlightViewV2()
}
