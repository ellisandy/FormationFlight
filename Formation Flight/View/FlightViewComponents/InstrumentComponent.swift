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
        VStack {
            withAnimation {
                Text(doubleToText() ?? "---")
                    .font(.headline)
                    .foregroundStyle(getStatusColor())
                    .padding(.top, 5)
                    .padding(.horizontal, 5)
            }
            Text(infoType.rawValue)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.bottom, 5)
        }
        .opacity(0.8)
    }
    // TODO: Extract this from the View file.
    func doubleToText() -> String? {
        // Shortcut to Nil
        guard infoValue != nil else { return nil }
        switch infoValue!.unit {
        case is UnitAngle:
            let formattedString = Measurement(value: infoValue!.value, unit: infoValue!.unit as! UnitAngle).converted(to: .degrees)
            
            if formattedString.value.isNaN || formattedString.value.isInfinite {
                return nil
            }
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
        
        let minutes = (time.truncatingRemainder(dividingBy: 3600) / 60).rounded()
        var seconds = (time.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60)).rounded()

        //Make sure it returns a positive value
        if seconds < 0 {
            seconds = seconds * -1
        }
        var secondString = ""
        
        switch seconds {

        case _ where seconds < 10:
            secondString = String(format: "0%.0f", seconds)
        default:
            secondString = String(format: "%.0f", seconds)
        }
        
        if minutes.isNaN || seconds.isNaN {
            return "---"
        }
        return "\(Int(minutes)):\(secondString)"
        
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
            return Color.white
        }
    }
}

#Preview {
    var config = SettingsEditorConfig.emptyConfig()
    config.speedUnit = .kts
    
    return InstrumentComponent(infoType: .tot, 
                               infoValue: .constant(Measurement(value: 625, unit: UnitDuration.seconds)),
                               infoStaus: .reallyBad,
                               settingsConfig: .constant(config))
}
