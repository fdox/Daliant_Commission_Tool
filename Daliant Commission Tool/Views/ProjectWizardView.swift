import SwiftUI

struct ProjectWizardView: View {
    @Environment(\.dismiss) private var dismiss

    // We’ll pass values back to the presenter. For Step 2a we only use title.
    var onCreate: (_ title: String,
                   _ contactFirst: String,
                   _ contactLast: String,
                   _ siteAddress: String,
                   _ controlSystemIndex: Int) -> Void

    @State private var title = ""
    @State private var first = ""
    @State private var last = ""
    @State private var address = ""
    @State private var controlSystemIndex = 0 // 0: Control4, 1: Crestron, 2: Lutron

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Project name", text: $title)
                        .textInputAutocapitalization(.words)
                }
                Section("Contact") {
                    TextField("First name", text: $first)
                        .textInputAutocapitalization(.words)
                    TextField("Last name", text: $last)
                        .textInputAutocapitalization(.words)
                }
                Section("Site") {
                    TextField("Site address", text: $address)
                        .textInputAutocapitalization(.words)
                }
                Section("Control system") {
                    Picker("Control system", selection: $controlSystemIndex) {
                        Text("Control4").tag(0)
                        Text("Crestron").tag(1)
                        Text("Lutron").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title, first, last, address, controlSystemIndex)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Wizard — Basic") {
    ProjectWizardView { _,_,_,_,_ in }
}
#endif//
//  ProjectWizardView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/24/25.
//

