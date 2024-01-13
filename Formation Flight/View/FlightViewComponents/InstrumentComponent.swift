//
//  InstrumentComponent.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/29/23.
//

import SwiftUI

struct InstrumentComponent: View {
    @State var infoType: InFlightInfo
    @Binding var infoValue: Double
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
    // TODO: Change Units as needed
    func doubleToText() -> String? {
        // Shortcut to Nil
        if infoValue == 0.0 { return nil }
        
        if self.infoType == .course {
            return infoValue.toBearingString()
        }
        
        if self.infoType == .tot || self.infoType == .totDrift {
            return infoValue.toTimeString()
        }
        
        if self.infoType == .currentTAS || self.infoType == .targetTAS {
            return infoValue.toAirSpeedString()
        }
        
        return String(self.infoValue)
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
    func getInFlightInfoType() -> String {
        switch infoType {
        case .tot:
            return "ToT"
        case .totDrift:
            return "Drift"
        case .targetTAS:
            return "Target GS"
        case .course:
            return "Course"
        case .currentTAS:
            return "GS"
        case .targetDistance:
            return "Distance"
        }
    }
    
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
    InstrumentComponent(infoType: .course, infoValue: .constant(30.0), infoStaus: .good, settingsConfig: .constant(.emptyConfig()))
}
