//
//  ExportView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/27/25.
//

import SwiftUI
import SwiftData

struct ExportView: View {
    let project: Item
    var orgName: String? = nil         // ← NEW
    @State private var lastURL: URL?
    @State private var status: String = ""
    @State private var isSharing = false
    
    // Pull all fixtures (sorted), then filter for this project in memory.
    @Query private var allFixtures: [Fixture]
    private var fixtures: [Fixture] {
        allFixtures.filter { $0.project?.id == project.id }
    }

    init(project: Item, orgName: String? = nil) {   // ← NEW defaulted param
            self.project = project
            self.orgName = orgName
            _allFixtures = Query(
                sort: [
                    SortDescriptor(\Fixture.label, order: .forward),
                    SortDescriptor(\Fixture.shortAddress, order: .forward)
                ]
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Export Commission PDF")
                .font(.title3).bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Now includes a paginated fixtures table with repeated header per page.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                generate()
            } label: {
                Label("Export PDF", systemImage: "doc.richtext")
            }
            .buttonStyle(.borderedProminent)
            
            JSONExportButton(project: project)
            JSONImportButton(project: project)

            if let url = lastURL {
                Text("Saved: \(url.lastPathComponent)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
#if os(iOS)
.sheet(isPresented: $isSharing) {
    if let url = lastURL {
        ShareSheet(items: [url])
    }
}
#endif
    }

    private func generate() {
        #if os(iOS)
        do {
            let exporter = PDFExporter()
            let url = try exporter.render(project: project, fixtures: fixtures) // <-- pass fixtures
            self.lastURL = url
            self.status = "PDF written to temporary folder."
            self.isSharing = true     // ← present the system share sheet
            print("Exported PDF → \(url.path)")
        } catch {
            self.status = "Export failed: \(error.localizedDescription)"
            print("Export failed: \(error)")
        }
        #endif
    }
}

#Preview {
    @MainActor in
    // In-memory SwiftData stack for Canvas
    let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Item.self, Fixture.self, configurations: cfg)

    let project = Item(title: "Smith Residence")
    project.controlSystemRaw = "Lutron QSX"
    project.contactFirstName = "Alex"
    project.contactLastName = "Smith"
    project.siteAddress = "123 Beach Ave, Miami, FL"
    project.createdAt = Date()
    
    // Seed a couple fixtures
       let f1 = Fixture(label: "Kitchen Pendants", shortAddress: 1, groups: 0b0001)
       f1.room = "Kitchen"; f1.dtTypeRaw = "DT6"; f1.serial = "K-PEND-001"
       let f2 = Fixture(label: "Great Room Downlights", shortAddress: 2, groups: 0b0010)
       f2.room = "Great Room"; f2.dtTypeRaw = "D4i"; f2.serial = "GR-DL-010"; f2.commissionedAt = Date()

       project.fixtures = [f1, f2]

    let ctx = container.mainContext
       ctx.insert(project); ctx.insert(f1); ctx.insert(f2)

       return ExportView(project: project)
           .modelContainer(container)
   }
