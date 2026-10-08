//
//  SettingsEditor.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/30/23.
//

import SwiftUI

struct SettingsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    // `@State` is the correct owner for an `@Observable` model created by the parent.
    @State var viewModel: SettingsEditorViewModel

    var body: some View {
        NavigationStack {
            SettingsEditorFormView(viewModel: viewModel)
                // D-03: name the screen for VoiceOver and for the user.
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.reset(userDefaults: UserDefaults.standard)
                            dismiss()
                        } label: {
                            Text("Cancel")
                        }
                    }

                    // B-32: instrument reordering enters edit mode the normal way
                    // instead of the form forcing `editMode = .active` permanently.
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }

                    ToolbarItem(placement: .topBarTrailing) {
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

