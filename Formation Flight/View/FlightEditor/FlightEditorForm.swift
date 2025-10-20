//
//  FlightEditorForm.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/24/23.
//

import SwiftUI
import Combine
import MapKit

struct FlightEditorForm: View {
    @Binding var config: FlightEditorConfig
    @State var checkPointPopover = false
    @State private var editingCheckpointIndex: Int? = nil
    
    var body: some View {
        NavigationStack {
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
                    ForEach(Array(config.flight.checkPoints.enumerated()), id: \.element.id) { index, checkPoint in
                        Button {
                            editingCheckpointIndex = index
                            checkPointPopover = true
                        } label: {
                            HStack {
                                Text(checkPoint.name)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(checkPoint.longitude)")
                                    Text("\(checkPoint.latitude)")
                                }
                            }
                        }
                    }
                    .onDelete(perform: { indexSet in
                        config.flight.checkPoints.remove(atOffsets: indexSet)
                    })
                    .onMove(perform: { indices, newOffset in
                        config.flight.checkPoints.move(fromOffsets: indices, toOffset: newOffset)
                    })
                    Button("New Check Point") {
                        editingCheckpointIndex = nil
                        checkPointPopover = true
                    }
                    .sheet(isPresented: $checkPointPopover) {
                        if let cpIndex = editingCheckpointIndex {
                            let currentName: String = config.flight.checkPoints[cpIndex].name
                            let currentCoordinate: CLLocationCoordinate2D = config.flight.checkPoints[cpIndex].getCLCoordinate()
                            CheckpointMapPickerView(name: currentName,
                                                    pinCoordinate: currentCoordinate,
                                                    onSave: { name, coordinate in
                                config.flight.checkPoints[cpIndex].name = name
                                config.flight.checkPoints[cpIndex].longitude = coordinate.longitude
                                config.flight.checkPoints[cpIndex].latitude = coordinate.latitude
                                checkPointPopover = false
                                return
                            },
                                                    onCancel: {
                                checkPointPopover = false
                                editingCheckpointIndex = nil
                                return
                            })
                        } else {
                            CheckpointMapPickerView { name, coordinate in
                                let clManager = CLLocationManager()
                                
                                clManager.startUpdatingLocation()
                                
                                let location = clManager.location ?? CLLocation(latitude: 0, longitude: 0)
                                
                                let cp = CheckPoint(name: name,
                                                    location: location)
                                config.flight.checkPoints.append(cp)
                                checkPointPopover = false
                                editingCheckpointIndex = nil
                            } onCancel: {
                                checkPointPopover = false
                                editingCheckpointIndex = nil
                            }
                        }
                    }

                }
            }
            .navigationTitle("Edit Flight")
            .toolbar { EditButton() }
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
