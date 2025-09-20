//
//  ExportView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/19/25.
//

import SwiftUI
import SwiftData

struct ProjectExportView: View {
    @Environment(\.modelContext) private var context
    @Query private var orgs: [Org]

    let project: Item

    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    // Derived
    private var fixtures: [Fixture] { project.fixtures.sorted { $0.shortAddress < $1.shortAddress } }
    private var orgName: String? { orgs.first?.name }

    var body: some View {
        Group {
            if isExporting {
                DSState.Loading(title: "Generating PDF", message: "Building report…")
            } else if let msg = errorMessage {
                DSState.ErrorView(title: "Export failed", message: msg, onRetry: { startExport() })
                    .padding(.vertical, DS.Spacing.md)
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Header
                    DSUI.SectionHeader("Export Project", subtitle: project.title) { EmptyView() }

                    // Summary
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text("Fixtures")
                            Spacer()
                            Text("\(fixtures.count)").foregroundStyle(.secondary)
                        }
                        if let cs = project.controlSystemRaw, !cs.isEmpty {
                            HStack {
                                Text("Control System")
                                Spacer()
                                Text(prettyControlSystem(cs)).foregroundStyle(.secondary)
                            }
                        }
                        if let site = project.siteAddress, !site.isEmpty {
                            HStack {
                                Text("Site")
                                Spacer()
                                Text(site).foregroundStyle(.secondary)
                            }
                        }
                        if let orgName, !orgName.isEmpty {
                            HStack {
                                Text("Organization")
                                Spacer()
                                Text(orgName).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)

                    // Actions
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            startExport()
                        } label: {
                            Label("Generate PDF", systemImage: "doc.richtext")
                        }
                        .buttonStyle(DSUI.PrimaryButtonStyle())
                        .disabled(fixtures.isEmpty)

                        if let url = exportedURL {
                            ShareLink(item: url) {
                                Label("Share PDF", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let url = exportedURL {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Last export")
                                .font(DS.Font.sub)
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .font(DS.Font.mono)
                                .textSelection(.enabled)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(DS.Spacing.lg)
            }
        }
        .animation(.default, value: isExporting)
        .animation(.default, value: errorMessage)
        .animation(.default, value: exportedURL)
    }

    private func startExport() {
        errorMessage = nil
        exportedURL = nil
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let url = try PDFExportService.shared.generate(project: project,
                                                               fixtures: fixtures,
                                                               orgName: orgName)
                exportedURL = url
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Local helper (mirrors Projects list pretty case)
private func prettyControlSystem(_ raw: String) -> String {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch s {
    case "control4", ".control4": return "Control4"
    case "crestron", ".crestron": return "Crestron"
    case "lutron", ".lutron":     return "Lutron"
    default: return raw.isEmpty ? "—" : raw
    }
}

#if DEBUG
#Preview("ExportView") {
    // Safe in‑memory container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, Fixture.self, configurations: config)
    let ctx = container.mainContext

    let org = Org(name: "Daliant Test Org"); ctx.insert(org)
    let p = Item(title: "Sample Project")
    p.controlSystemRaw = "lutron"; p.siteAddress = "123 Ocean Ave"; p.createdAt = Date()
    ctx.insert(p)

    let fx = Fixture(label: "Kitchen Cans", shortAddress: 3, groups: 1)
    fx.room = "Kitchen"; fx.dtTypeRaw = "DT8"; fx.project = p
    ctx.insert(fx)

    return NavigationStack {
        ProjectExportView(project: p)
    }.modelContainer(container)
}
#endif
