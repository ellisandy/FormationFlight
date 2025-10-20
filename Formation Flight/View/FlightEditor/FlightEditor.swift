//
//  FlightEditor.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/24/23.
//

import SwiftUI

struct FlightEditor: View {
    @Binding var config: FlightEditorConfig
    
    var body: some View {
        NavigationStack {
            FlightEditorForm(config: $config)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(editorTitle)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            config.cancel()
                        } label: {
                            Text("Cancel")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            //TODO: Validate the inform data
                            
                            config.done()
                        } label: {
                            Text("Save")
                        }
                    }
                }
        }
    }
    private var editorTitle: String {
        config.flight.title == "" ? "Add Flight" : "Edit Flight"
    }
}

#Preview {
    FlightEditor(config: .constant(FlightEditorConfig()))
}
