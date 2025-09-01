//
//  JSONImportButton.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Button that imports a ProjectDTO from JSON, then either:
/// - Creates a new project, or
/// - Merges fixtures into the current project (dedupe by serial/address).
struct JSONImportButton: View {
    let project: Item

    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var pendingDTO: ProjectDTO?
    @State private var showChoice = false

    @State private var resultSummary: ImportSummary?
    @State private var newProjectTitle: String?

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Button {
            showImporter = true
        } label: {
            Label("Import JSON", systemImage: "tray.and.arrow.down")
        }
        .buttonStyle(.bordered)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let dto = try JSONImporter.loadProjectDTO(from: url)
                    pendingDTO = dto
                    showChoice = true
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .confirmationDialog("Import Options", isPresented: $showChoice, titleVisibility: .visible) {
            Button("Create New Project from JSON") {
                guard let dto = pendingDTO else { return }
                do {
                    let result = try JSONImporter.createProject(from: dto, in: modelContext)
                    resultSummary = result.summary
                    newProjectTitle = result.project.title
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            Button("Merge into Current Project") {
                guard let dto = pendingDTO else { return }
                do {
                    let summary = try JSONImporter.merge(dto: dto, into: project, in: modelContext)
                    resultSummary = summary
                    newProjectTitle = nil
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(resultAlertTitle, isPresented: Binding(
            get: { resultSummary != nil },
            set: { if !$0 { resultSummary = nil; newProjectTitle = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let summary = resultSummary {
                if let newTitle = newProjectTitle {
                    Text("Created “\(newTitle)”.\nFixtures — Added: \(summary.created), Updated: \(summary.updated), Skipped: \(summary.skipped).")
                } else {
                    Text("Merged into current project.\nFixtures — Added: \(summary.created), Updated: \(summary.updated), Skipped: \(summary.skipped).")
                }
            }
        }
        .alert("Import Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
        .accessibilityIdentifier("ImportJSONButton")
    }

    private var resultAlertTitle: String {
        newProjectTitle == nil ? "Import Complete" : "Project Created"
    }
}

#Preview("Import JSON Button") {
    JSONImportButton(project: Item(title: "Preview Project"))
}
