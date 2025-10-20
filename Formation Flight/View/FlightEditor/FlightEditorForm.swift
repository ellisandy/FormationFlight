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
                DatePicker("Mission Date", selection: $config.flight.missionDate, displayedComponents: [.date, .hourAndMinute])
            }
            Section("Wind Conditions") {
                HStack {
                    Text("Direction:").fontWeight(.thin)

                    TextField(value: $config.flight.expectedWinds.directionAsDegrees,
                              formatter: windInputFormatter,
                              prompt: Text("Wind Direction")) {
                        Text("Wind Direction")
                    }
                          .keyboardType(.numberPad)
                }

                HStack {
                    Text("Velocity:  ").fontWeight(.thin)

                    TextField("Wind Velocity",
                              value: $config.flight.expectedWinds.velocityAsKnots,
                              formatter: windInputFormatter)
                    .keyboardType(.numberPad)
                }
            }
            Section("Flight Plan") {
                ForEach(config.flight.checkPoints) { checkPoint in
                    HStack {
                        Text(checkPoint.name)
                        Spacer()
                        VStack {
                            Text("\(checkPoint.longitude)")
                            Text("\(checkPoint.latitude)")
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
            }
        }
    }
 
    let windInputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = false
        formatter.maximumFractionDigits = 0
        return formatter
    }()

}

#Preview {
    FlightEditorForm(config: .constant(FlightEditorConfig()))
}

