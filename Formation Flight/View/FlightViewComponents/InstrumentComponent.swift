//
//  InstrumentComponent.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import SwiftUI

struct InstrumentComponent: View {
    @State var infoType: InFlightInfo
    @Binding var infoValue: Measurement<Dimension>?
    @State var infoStaus: InfoStatus
    @Binding var settingsConfig: SettingsEditorConfig
    
    var body: some View {
        VStack(alignment: .center) {
            withAnimation {
                Text(doubleToText() ?? "---")
                    .font(.title)
                    .foregroundStyle(getStatusColor())
                    .padding(.top, 5)
            }
            Text(infoType.rawValue)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 5)
        }
        .padding(.horizontal, 5)
    }
    
    // TODO: Extract this from the View file.
    func doubleToText() -> String? {
        // Shortcut to Nil
        guard infoValue != nil else { return nil }
        guard infoValue!.value.isFinite else { return nil }
        
        switch infoValue!.unit {
        case is UnitAngle:
            let formattedString = Measurement(value: infoValue!.value, unit: infoValue!.unit as! UnitAngle).converted(to: .degrees)

            return formattedString.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))
        case is UnitLength:
            let formattedString = Measurement(value: infoValue!.value, unit: infoValue!.unit as! UnitLength).converted(to: .nauticalMiles)
            return formattedString.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))))
        case is UnitSpeed:
            let formattedString = Measurement(value: infoValue!.value, unit: infoValue!.unit as! UnitSpeed).converted(to: settingsConfig.getUnitSpeed())
            return formattedString.formatted(.measurement(width: .narrow, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
        case is UnitDuration:
            let formattedString = Measurement(value: infoValue!.value, unit: infoValue!.unit as! UnitDuration)

            return formattedString.formatted(TimeFormatter())
        default:
            return nil
        }
    }
}

struct TimeFormatter: FormatStyle {
    func format(_ value: Measurement<UnitDuration>) -> String {
        let time = value.value
        
        if (7200.0).isLessThanOrEqualTo(time) || time.isLessThanOrEqualTo(-7200.0) {
            return "---"
        }
        
        var minutes = (time.truncatingRemainder(dividingBy: 3600) / 60)
        var seconds = (time.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60))
        
        if seconds.isLess(than: 0.0) {
            seconds.negate()
        }
        
        if minutes.isLessThanOrEqualTo(0.0) {
            minutes.negate()
        }
        
        var secondString = ""
        
        switch seconds {
        case _ where seconds < 10:
            //Make sure it returns a positive value
            secondString = String(format: "0%.0f", seconds)
            secondString = secondString.filter { $0 != "-" }
        default:
            secondString = String(format: "%.0f", seconds)
        }
        
        if minutes.isNaN || seconds.isNaN {
            return "---"
        }
        let sign = {
            if time.isLess(than: 0.0) {
                return "-"
            }
            return ""
        }()
        
        return "\(sign)\(Int(minutes)):\(secondString)"
    }

}

enum InFlightInfo: String, CaseIterable {
    case tot = "ToT"
    case totDrift = "Drift"
    case targetTAS = "Target TAS"
    case targetDistance =  "Distance"
    case course = "Heading"
    case currentTAS = "Current TAS"
    
}

enum InfoStatus {
    case good
    case bad
    case reallyBad
    case nutrual
}

extension InstrumentComponent {
    func getStatusColor() -> Color {        
        switch infoStaus {
        case .reallyBad:
            return Color.red
        case .bad:
            return Color.yellow
        case .good:
            return Color.green
        case .nutrual:
            return .primary
        }
    }
}

#Preview("positive", traits: .sizeThatFitsLayout) {
    var config = SettingsEditorConfig.emptyConfig()
    config.speedUnit = .kts
    
    return InstrumentComponent(infoType: .tot, 
                               infoValue: .constant(Measurement(value: 625, unit: UnitDuration.seconds)),
                               infoStaus: .reallyBad,
                               settingsConfig: .constant(config))
}

#Preview("Negative", traits: .sizeThatFitsLayout) {
    var config = SettingsEditorConfig.emptyConfig()
    config.speedUnit = .kts
    
    return InstrumentComponent(infoType: .tot,
                               infoValue: .constant(Measurement(value: -625, unit: UnitDuration.seconds)),
                               infoStaus: .good,
                               settingsConfig: .constant(config))
}

#Preview {
    let panelData = InstrumentPanelData(
        currentETA: Measurement(value: 600.0, unit: UnitDuration.seconds),
        ETADelta: Measurement(value: 600.0, unit: UnitDuration.seconds),
        course: Measurement(value: 180, unit: UnitAngle.degrees),
        currentTrueAirSpeed: Measurement(value: 100, unit: UnitSpeed.metersPerSecond),
        targetTrueAirSpeed: Measurement(value: 100, unit: UnitSpeed.metersPerSecond),
        distanceToNext: Measurement(value: 10, unit: UnitLength.meters),
        distanceToFinal: Measurement(value: 10, unit: UnitLength.meters))
    
    InstrumentPanel(
        settingsConfig: .constant(SettingsEditorConfig(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, minSpeed: 100, maxSpeed: 160)),
        panelData: panelData,
        isFlightViewPresented: .constant(true), flight: .constant(Flight.emptyFlight()))
}
