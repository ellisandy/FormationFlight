//
//  SettingsEditor.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: SettingsEditorViewModel
    
    var body: some View {
        NavigationStack {
            SettingsEditorForm(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewModel.reset(userDefaults: UserDefaults.standard)
                            dismiss()
                        } label: {
                            Text("Cancel")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.save(userDefaults: UserDefaults.standard)
                            dismiss()
                        } label: {
                            Text("Save")
                        }
                    }
                    
                }
        }
        
    }
}

#Preview {
    SettingsEditorView(viewModel: SettingsEditorViewModel(settings: Settings(speedUnit: .kts, distanceUnit: .nm, yellowTolerance: 5, redTolerance: 10, instrumentSettings: [])))
}

