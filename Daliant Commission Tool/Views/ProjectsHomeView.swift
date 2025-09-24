import SwiftUI
import SwiftData

struct ProjectsHomeView: View {
    @Environment(\.modelContext) private var context
    @State private var showingSettings = false
    @State private var query: String = ""
    @State private var showingWizard = false
    @Query private var projects: [Item]

    var body: some View {
        NavigationStack {
            content(for: filteredProjects())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Projects")
                            .font(DS.Font.title)
                    }
                    // + button
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingWizard = true
                        } label: {
                            Label("New Project", systemImage: "plus")
                        }
                    }
                    // gear button
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                // Settings sheet
                .sheet(isPresented: $showingSettings) {
                    NavigationStack { SettingsView() }
                }
                // Wizard sheet
            // Wizard sheet
            .sheet(isPresented: $showingWizard) {
                ProjectWizardView { title, first, last, address, csIndex in
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }

                    let newProject = Item(title: t)

                    // Save Step 2b fields (safe trims)
                    let f = first.trimmingCharacters(in: .whitespacesAndNewlines)
                    let l = last.trimmingCharacters(in: .whitespacesAndNewlines)
                    let a = address.trimmingCharacters(in: .whitespacesAndNewlines)
                    newProject.contactFirstName = f.isEmpty ? nil : f
                    newProject.contactLastName  = l.isEmpty ? nil : l
                    newProject.siteAddress      = a.isEmpty ? nil : a
                    let options = ["control4", "crestron", "lutron"]
                    newProject.controlSystemRaw = (0..<options.count).contains(csIndex) ? options[csIndex] : options[0]
                    newProject.createdAt = Date()
                    newProject.updatedAt = Date()

                    withAnimation {
                        context.insert(newProject)
                        try? context.save()
                        query = ""  // clear search so the row is visible
                    }

                    // Push to Firestore (fire-and-forget)
                    Task {
                        do {
                            try await ProjectSyncService.shared.push(newProject, context: context)
                            #if DEBUG
                            print("[Projects] Pushed project \(newProject.title)")
                            #endif
                        } catch {
                            #if DEBUG
                            print("[Projects] Push failed: \(error.localizedDescription)")
                            #endif
                        }
                    }
                }
                .environment(\.modelContext, context)
            }

        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }


    @ViewBuilder
    private func content(for items: [Item]) -> some View {
        if items.isEmpty {
            DSState.Empty(
                title: "No Projects",
                systemImage: "folder",
                message: "Tap + to add your first project."
            )
            .padding()
        } else {
            projectsList(items)
        }

    }

    private func projectsList(_ items: [Item]) -> some View {
        List {
            ForEach(items, id: \.persistentModelID) { p in
                NavigationLink {
                    ProjectDetailView(project: p)
                } label: {
                    ProjectCardRow(
                        name: p.title,
                        controlSystemTag: projectControlSystemTag(p),
                        contact: projectContact(p),
                        created: p.updatedAt ?? p.createdAt
                    )

                }
                // 11g: archive swipe
                .swipeActions {
                    Button(role: .destructive) {
                        archive(p)
                    } label: {
                        Text("Archive")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.lg, bottom: DS.Spacing.sm, trailing: DS.Spacing.lg))
                .background(Color.clear)
            }
        }
        .listStyle(.plain)
    }
    
    private func filteredProjects() -> [Item] {
        let base = projects
            .filter { $0.archivedAt == nil }  // 11g: hide archived
            .sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Safe accessors
    // MARK: - Reflection helpers that handle Optional values

    /// Unwraps Optional<T> to T using reflection; returns the original value if not optional.
    private func unwrapOptional(_ any: Any) -> Any? {
        let m = Mirror(reflecting: any)
        guard m.displayStyle == .optional else { return any }
        return m.children.first?.value
    }

    /// Extracts a non-empty String from `any`, handling `String` or `Optional<String>`.
    private func stringValue(_ any: Any?) -> String? {
        guard let any = any else { return nil }
        if let s = any as? String { return s.isEmpty ? nil : s }
        if let unwrapped = unwrapOptional(any) as? String { return unwrapped.isEmpty ? nil : unwrapped }
        return nil
    }

    /// Reads a (possibly Optional) String property by name from a model instance.
    private func getString(_ model: Any, key: String) -> String? {
        let mirror = Mirror(reflecting: model)
        guard let val = mirror.children.first(where: { $0.label == key })?.value else { return nil }
        return stringValue(val)
    }

    // MARK: - Project field accessors (now robust to optionals)
    

    private func projectControlSystemTag(_ item: Item) -> String? {
        guard let raw = item.controlSystemRaw?.lowercased() else { return nil }
        switch raw {
        case "control4": return "Control4"
        case "crestron": return "Crestron"
        case "lutron":   return "Lutron"
        default:         return nil
        }
    }
    

    private func projectContact(_ item: Item) -> String? {
        let first = getString(item, key: "contactFirstName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let last  = getString(item, key: "contactLastName")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [first, last].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
    private func prettyControlSystem(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "control4", ".control4": return "Control4"
        case "crestron", ".crestron": return "Crestron"
        case "lutron", ".lutron":     return "Lutron"
        default: return raw.isEmpty ? "—" : raw
        }
    }
    // 11g: helper called by the swipe action
    private func archive(_ item: Item) {
        item.archivedAt = Date()
        AutosaveCenter.shared.touch(item, context: context)
        Task { @MainActor in
            do {
                try await ProjectSyncService.shared.push(item, context: context)
            } catch {
                print("[Archive] push error: \(error.localizedDescription)")
            }
        }
    }
}

struct ProjectCardRow: View {
    let name: String
    let controlSystemTag: String?
    let contact: String?
    let created: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(name)
                .font(DS.Font.heading)
                .lineLimit(1)

            HStack(spacing: DS.Spacing.sm) {
                if let tag = controlSystemTag {
                    // Present control system as a semantic badge
                    DSUI.SemanticBadge(kind: .info, text: tag, systemImage: "bolt.fill")
                        .accessibilityLabel("Control system \(tag)")
                }

                if let contact, !contact.isEmpty {
                    Text(contact)
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.md)

                if let created {
                    Text(created, format: .dateTime.month(.abbreviated).day().year())
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel("Last updated \(created.formatted(.dateTime.month().day().year()))")
                }
            }
        }
        .padding(DS.Card.padding)
        .background(
            RoundedRectangle(cornerRadius: DS.Card.corner, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Card.corner, style: .continuous)
                .strokeBorder(Color.secondary.opacity(DS.Opacity.hairline), lineWidth: DS.Line.hairline)
        )
        .contentShape(Rectangle())
    }
}


    
    // MARK: - Preview helper (seed OUTSIDE the #Preview)
    fileprivate enum PreviewFactory {
        @MainActor
        static func projectsHome() -> some View {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
            let context = container.mainContext
            
            let org = Org(name: "Dox Electronics")
            context.insert(org)
            
            // Your Item model currently uses 'title:'
            let p1 = Item(title: "Smith Residence")
            p1.controlSystemRaw = "lutron"
            p1.contactFirstName = "Alex"
            p1.contactLastName  = "Smith"
            
            _ = try? context.save()
            return ProjectsHomeView().modelContainer(container)
        }
    }
    
#if DEBUG
private struct ProjectsHomePreviewHost: View {
    @Environment(\.modelContext) private var ctx
    @Query private var items: [Item]

    var body: some View {
        NavigationStack { ProjectsHomeView() }
            // Seed once when the preview starts
            .task { @MainActor in
                if items.isEmpty { seed() }
            }
    }

    @MainActor
    private func seed() {
        let org = Org(name: "Daliant Test Org")
        ctx.insert(org)

        let p1 = Item(title: "Smith Residence")
        p1.createdAt = Date()
        p1.contactFirstName = "Alex"
        p1.contactLastName  = "Smith"
        p1.controlSystemRaw = "lutron"
        ctx.insert(p1)

        try? ctx.save()
    }
}

#Preview("Projects — Seeded") {
    ProjectsHomePreviewHost()
        .modelContainer(for: [Org.self, Item.self, Fixture.self], inMemory: true)
}
#endif
