#!/usr/bin/env bash
set -euo pipefail

# Phase 3 — Step 1:
# - Fix Projects list to use Item.name and avoid fragile IDs.
# - Restore Settings with org name + join code, "Join different org", and Sign out.
# - Add Canvas #Previews with in-memory SwiftData containers.
# - Auto-detect the Views folder.

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "❌ Run this from within your Git repository (repo root)."
  exit 1
}

# Detect the Views folder
if [ -d "Views" ]; then
  VIEWS_DIR="Views"
elif [ -d "Daliant Commission Tool/Views" ]; then
  VIEWS_DIR="Daliant Commission Tool/Views"
elif [ -d "Daliant_Commission_Tool/Views" ]; then
  VIEWS_DIR="Daliant_Commission_Tool/Views"
else
  VIEWS_DIR="Views"
  mkdir -p "$VIEWS_DIR"
fi

#############################################
# Write ProjectsHomeView.swift
#############################################
cat > "$VIEWS_DIR/ProjectsHomeView.swift" <<'SWIFT'
//  ProjectsHomeView.swift
//  Daliant Commission Tool
//
//  Phase 3 – Step 1 update:
//  - Uses Item.name (not Item.title)
//  - Adds simple search
//  - Gear button opens SettingsView
//  - Canvas-friendly preview with in-memory SwiftData

import SwiftUI
import SwiftData

struct ProjectsHomeView: View {
    @Environment(\.modelContext) private var context
    @State private var showingSettings = false
    @State private var query: String = ""

    @Query private var projects: [Item]

    var body: some View {
        NavigationStack {
            Group {
                let filtered = filteredProjects()
                if filtered.isEmpty {
                    ContentUnavailableView("No Projects",
                                           systemImage: "folder",
                                           description: Text("Tap + (coming soon) or use the wizard to create your first project."))
                        .padding()
                } else {
                    List {
                        ForEach(filtered) { p in
                            NavigationLink {
                                // Replace this stub with your Project Detail screen when ready.
                                Text("Project Detail (coming soon)")
                                    .navigationTitle(projectName(p))
                            } label: {
                                ProjectCardRow(name: projectName(p),
                                               controlSystemTag: projectControlSystemTag(p),
                                               contact: projectContact(p))
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .background(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }

    private func filteredProjects() -> [Item] {
        let base = projects.sorted {
            projectName($0).localizedStandardCompare(projectName($1)) == .orderedAscending
        }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        return base.filter { projectName($0).localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Safe accessors (avoid compile breaks if model fields change)

    private func projectName(_ item: Item) -> String {
        if let n = Mirror(reflecting: item).children.first(where: { $0.label == "name" })?.value as? String, !n.isEmpty {
            return n
        }
        if let t = Mirror(reflecting: item).children.first(where: { $0.label == "title" })?.value as? String, !t.isEmpty {
            return t
        }
        return "Untitled"
    }

    private func projectControlSystemTag(_ item: Item) -> String? {
        if let raw = Mirror(reflecting: item).children.first(where: { $0.label == "controlSystemRaw" })?.value as? String, !raw.isEmpty {
            return prettyControlSystem(raw)
        }
        if let enumVal = Mirror(reflecting: item).children.first(where: { $0.label == "controlSystem" })?.value {
            let s = String(describing: enumVal)
            return prettyControlSystem(s)
        }
        return nil
    }

    private func projectContact(_ item: Item) -> String? {
        let mirror = Mirror(reflecting: item)
        let first = mirror.children.first(where: { $0.label == "contactFirstName" })?.value as? String
        let last  = mirror.children.first(where: { $0.label == "contactLastName" })?.value as? String
        let full = [first, last].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? nil : full
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
}

private struct ProjectCardRow: View {
    let name: String
    let controlSystemTag: String?
    let contact: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 8) {
                if let tag = controlSystemTag {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .accessibilityLabel("Control system \(tag)")
                }
                if let contact {
                    Text(contact)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview("Projects – Seeded") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    let context = container.mainContext

    do {
        let org = Org(name: "Dox Electronics", joinCode: "DOX123")
        context.insert(org)

        let p1 = Item(name: "Smith Residence")
        let p2 = Item(name: "Beach House")
        context.insert(p1)
        context.insert(p2)
        try context.save()
    } catch {
        assertionFailure("Preview seeding failed: \(error)")
    }

    return ProjectsHomeView()
        .modelContainer(container)
}
SWIFT

#############################################
# Write SettingsView.swift
#############################################
cat > "$VIEWS_DIR/SettingsView.swift" <<'SWIFT'
//  SettingsView.swift
//  Daliant Commission Tool
//
//  Phase 3 – Step 1 update:
//  - Shows current Org name + join code
//  - "Join different org" by code (local behavior)
//  - "Sign out" deletes all Org records
//  - Canvas #Preview with in-memory SwiftData

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var orgs: [Org]

    @State private var newJoinCode: String = ""
    @State private var errorMessage: String?

    var currentOrg: Org? { orgs.first }

    var body: some View {
        Form {
            Section("Organization") {
                HStack {
                    Text("Name").foregroundStyle(.secondary)
                    Spacer()
                    Text(currentOrgName())
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Join code").foregroundStyle(.secondary)
                    Spacer()
                    Text(currentOrgJoinCode())
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
            }

            Section("Join different org") {
                TextField("Enter join code", text: $newJoinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Join") {
                    joinDifferentOrg()
                }
                .disabled(newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                Button(role: .destructive) {
                    signOut()
                } label: {
                    Text("Sign out")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    // MARK: - Helpers

    private func currentOrgName() -> String {
        guard let org = currentOrg else { return "—" }
        if let n = Mirror(reflecting: org).children.first(where: { $0.label == "name" })?.value as? String, !n.isEmpty {
            return n
        }
        return "—"
    }

    private func currentOrgJoinCode() -> String {
        guard let org = currentOrg else { return "—" }
        if let c = Mirror(reflecting: org).children.first(where: { $0.label == "joinCode" })?.value as? String, !c.isEmpty {
            return c
        }
        return "—"
    }

    private func joinDifferentOrg() {
        let code = newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        do {
            let fetch = FetchDescriptor<Org>()
            let all = try context.fetch(fetch)
            if let found = all.first(where: {
                (Mirror(reflecting: $0).children.first(where: { $0.label == "joinCode" })?.value as? String)?
                    .caseInsensitiveCompare(code) == .orderedSame
            }) {
                for o in all where o != found { context.delete(o) }
                try context.save()
                newJoinCode = ""
                return
            }

            for o in all { context.delete(o) }
            let newOrg = Org(name: "Org (\(code))", joinCode: code)
            context.insert(newOrg)
            try context.save()
            newJoinCode = ""
        } catch {
            errorMessage = "Could not switch org: \(error.localizedDescription)"
        }
    }

    private func signOut() {
        do {
            let fetch = FetchDescriptor<Org>()
            for o in try context.fetch(fetch) {
                context.delete(o)
            }
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}

#Preview("Settings – Seeded") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    let context = container.mainContext

    do {
        let org = Org(name: "Dox Electronics", joinCode: "DOX123")
        context.insert(org)
        try context.save()
    } catch {
        assertionFailure("Preview seed failed: \(error)")
    }

    return NavigationStack {
        SettingsView()
    }
    .modelContainer(container)
}
SWIFT

git add "$VIEWS_DIR/ProjectsHomeView.swift" "$VIEWS_DIR/SettingsView.swift"
git commit -m "Phase 3 – Step 1: Fix Projects list (Item.name); restore Settings (org name + join code, join different org, sign out) with Canvas previews."
git push origin main || {
  echo "⚠️  git push failed (no remote or auth?). Commit is still created locally."
}
echo "✅ Done. Open ProjectsHomeView and SettingsView in Canvas to verify."
