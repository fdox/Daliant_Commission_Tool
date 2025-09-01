//
//  JSONExportButton.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import SwiftUI
import SwiftData

/// Drop-in button to export the given project to JSON and present the Share Sheet.
struct JSONExportButton: View {
    let project: Item

    @State private var shareURL: URL?
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            do {
                let url = try JSONExporter.exportProject(project)
                shareURL = url
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        } label: {
            Label("Export JSON", systemImage: "doc.text")
        }
        .buttonStyle(.bordered) // Keep PDF as the primary action; JSON is secondary.
        .padding(.top, 8)
        .sheet(isPresented: Binding(get: { shareURL != nil },
                                    set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL {
                // Uses your existing UIActivityViewController wrapper from Step 8c.
                // If your initializer is `activityItems:`, just change the label below.
                ShareSheet(items: [url])
            }
        }
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
        .accessibilityIdentifier("ExportJSONButton")
    }
}

// Simple preview; no share sheet shown until tapped.
#Preview("Export JSON Button") {
    JSONExportButton(project: Item(title: "Sample Project"))
}
