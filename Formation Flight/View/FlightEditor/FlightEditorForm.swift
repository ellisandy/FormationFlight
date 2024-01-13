//
//  FlightEditorForm.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/24/23.
//

import SwiftUI
import Combine

struct FlightEditorForm: View {
    @Binding var config: FlightEditorConfig
    @State var checkPointPopover = false
    
    var body: some View {
        Form{
            Section(header: Text("Flight Overview")) {
                TextField("Mission Title", text: $config.flight.title)
                DatePicker("Planned Intercept", selection: $config.flight.interceptTime, displayedComponents: [.date, .hourAndMinute])
                Stepper(value: $config.flight.targetAltitude,
                        in: 300...2000,
                        step: 50)  {
                    HStack {
                        Text("Target Altitude:")
                        Text("\(Int(config.flight.targetAltitude))' AGL").dynamicTypeSize(.medium).bold()
                    }
                }
                Stepper(value: $config.flight.targetSpeed,
                        in: 50...300,
                        step: 1) {
                    HStack {
                        Text("Target Speed:")
                        Text("\(Int(config.flight.targetSpeed)) Knots").dynamicTypeSize(.medium).bold()
                    }
                }
            }
            Section("Conditions") {
                TextField(text: $config.flight.expectedWinds.windDirectionAsText, prompt: Text("Wind Direction")) {
                    Text("Wind Direction")
                }

                TextField(text: $config.flight.expectedWinds.windVelocityAsText, prompt: Text("Wind Velocity")) {
                    Text("Wind Velocity")
                }
            }
            Section("Flight Plan") {
                ForEach($config.flight.checkPoints) { checkPoint in
                    HStack {
                        Text(checkPoint.name.wrappedValue)
                        Spacer()
                        VStack {
                            Text("\(checkPoint.longitude.wrappedValue)")
                            Text("\(checkPoint.latitude.wrappedValue)")
                        }
                    }
                }
                .onDelete(perform: { indexSet in
                    config.flight.checkPoints.remove(atOffsets: indexSet)
                })
                .onMove(perform: { indices, newOffset in
                    config.flight.checkPoints.move(fromOffsets: indices, toOffset: newOffset)
                })
                FlightEditorCheckPoint(flight: config.flight)
                Button(role: .destructive) {
                    config.flight.checkPoints = [BVS_LOCATION, HOME_LOCATION, TREE_FARM_LOCATION]
                } label: {
                    Text("DEFAULT SET")
                }

            }
        }
    }
    
    //TODO: Refactor these away...probably
    let windDirectionFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = .init(integerLiteral: 0)
        formatter.maximum = .init(integerLiteral: 360)
        formatter.generatesDecimalNumbers = false
        formatter.maximumFractionDigits = 0
        formatter.zeroSymbol = ""
        formatter.numberStyle = .none
        return formatter
    }()
    
    let windVelocityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = .init(integerLiteral: 0)
        formatter.maximum = .init(integerLiteral: Int.max)
        formatter.generatesDecimalNumbers = false
        formatter.maximumFractionDigits = 0
        formatter.zeroSymbol = ""
        formatter.numberStyle = .none
        return formatter
    }()

}

#Preview {
    FlightEditorForm(config: .constant(FlightEditorConfig()))
}
