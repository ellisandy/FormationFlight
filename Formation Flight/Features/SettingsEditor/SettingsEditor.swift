//
//  SettingsEditor.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditor: View{
    @Binding var settingsEditorConfig: SettingsEditorConfig

    var body: some View {
        NavigationStack {
                SettingsEditorForm(settingsEditorConfig: $settingsEditorConfig)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        settingsEditorConfig.reset(userDefaults: UserDefaults.standard)
                        settingsEditorConfig.dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        settingsEditorConfig.save(userDefaults: UserDefaults.standard)
                        settingsEditorConfig.dismiss()
                    } label: {
                        Text("Save")
                    }
                }

            }
        }
        
    }
}

#Preview {
    SettingsEditor(settingsEditorConfig: .constant(SettingsEditorConfig.emptyConfig()))
}
