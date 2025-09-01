#!/usr/bin/env bash
set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "❌ Run this from within your Git repository."
  exit 1
}

# --- Locate Views folder ---
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

# --- Overwrite ProjectsHomeView.swift (no 'return' in previews) ---
cat > "$VIEWS_DIR/ProjectsHomeView.swift" <<'SWIFT'
//  ProjectsHomeView.swift
//  Daliant Commission Tool
//
//  Phase 3 – Step 1c:
//  - Uses Item.name
//  - Search + gear -> Settings
//  - Preview: removed 'return' (result builder), in-memory SwiftData

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
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Tap + (coming soon) or use the wizard to create your first project.")
                    )
                    .padding()
                } else {
                    List {
                        ForEach(filtered) { p in
                            NavigationLink {
                                Text("Project Detail (coming soon)")
                                    .navigationTitle(projectName(p))
                            } label: {
                                ProjectCardRow(
                                    name: projectName(p),
                                    controlSystemTag: projectControlSystemTag(p),
                                    contact: projectContact(p)
                                )
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

    // MARK: - Safe accessors

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
        let m = Mirror(reflecting: item)
        let first = m.children.first(where: { $0.label == "contactFirstName" })?.value as? String
        let last  = m.children.first(where: { $0.label == "contactLastName" })?.value as? String
        let full = [first, last]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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

#Preview("Projects — Seeded") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    let context = container.mainContext

    do {
        let org = Org(name: "Dox Electronics")  // no joinCode: init
        context.insert(org)

        let p1 = Item(name: "Smith Residence")
        let p2 = Item(name: "Beach House")
        context.insert(p1)
        context.insert(p2)
        try context.save()
    } catch {
        assertionFailure("Preview seeding failed: \(error)")
    }

    ProjectsHomeView()
        .modelContainer(container)
}
SWIFT

# --- Overwrite SettingsView.swift (no 'return' in preview, no joinCode: inits) ---
cat > "$VIEWS_DIR/SettingsView.swift" <<'SWIFT'
//  SettingsView.swift
//  Daliant Commission Tool
//
//  Phase 3 – Step 1c:
//  - Display org name + join code (if present) with fallbacks
//  - Join different org by code (local behavior)
//  - Sign out (delete all orgs)
//  - Preview: removed 'return' (result builder)

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
                Button("Join") { joinDifferentOrg() }
                    .disabled(newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                Button(role: .destructive) { signOut() } label: { Text("Sign out") }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
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
        let m = Mirror(reflecting: org)
        if let c = m.children.first(where: { $0.label == "joinCode" })?.value as? String, !c.isEmpty {
            return c
        }
        if let c = m.children.first(where: { $0.label == "code" })?.value as? String, !c.isEmpty {
            return c
        }
        // Fallback: parse from name like "Org (DOX123)"
        if let name = m.children.first(where: { $0.label == "name" })?.value as? String,
           let parsed = parseCodeFromName(name) {
            return parsed
        }
        return "—"
    }

    private func parseCodeFromName(_ name: String) -> String? {
        guard let open = name.lastIndex(of: "("),
              let close = name.lastIndex(of: ")"),
              close > open
        else { return nil }
        let code = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }

    private func joinDifferentOrg() {
        let code = newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        do {
            let fetch = FetchDescriptor<Org>()
            let all = try context.fetch(fetch)

            // Try match by joinCode or code property.
            if let found = all.first(where: {
                let m = Mirror(reflecting: $0)
                let c1 = (m.children.first(where: { $0.label == "joinCode" })?.value as? String)
                let c2 = (m.children.first(where: { $0.label == "code" })?.value as? String)
                let name = (m.children.first(where: { $0.label == "name" })?.value as? String) ?? ""
                return c1?.caseInsensitiveCompare(code) == .orderedSame
                    || c2?.caseInsensitiveCompare(code) == .orderedSame
                    || name.localizedCaseInsensitiveContains("(\(code))")
            }) {
                for o in all where o != found { context.delete(o) }
                try context.save()
                newJoinCode = ""
                return
            }

            // Otherwise create a simple Org with the code in the name as a fallback.
            for o in all { context.delete(o) }
            let newOrg = Org(name: "Org (\(code))")
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

#Preview("Settings — Seeded") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    let context = container.mainContext

    do {
        let org = Org(name: "Dox Electronics") // no joinCode: init
        context.insert(org)
        try context.save()
    } catch {
        assertionFailure("Preview seed failed: \(error)")
    }

    NavigationStack { SettingsView() }
        .modelContainer(container)
}
SWIFT

# --- Patch SignInView.swift preview: remove 'return' inside #Preview blocks only ---
FILE="$VIEWS_DIR/SignInView.swift"
if [[ -f "$FILE" ]]; then
  cp "$FILE" "$FILE.bak"

  /usr/bin/python3 <<'PY'
import sys, re, os
path = os.environ["FILE"]
with open(path, "r") as f:
    src = f.read()

out = []
i = 0
n = len(src)
inside_preview = False
brace_depth = 0

for line in src.splitlines(keepends=False):
    stripped = line.lstrip()
    # Detect entering a #Preview block (simple heuristic)
    if stripped.startswith("#Preview"):
        inside_preview = True
        brace_depth = 0
        out.append(line)
        continue

    if inside_preview:
        brace_depth += line.count("{") - line.count("}")
        # Remove leading 'return ' only while inside preview body
        if stripped.startswith("return "):
            # drop 'return ' but keep the expression after it
            leading_ws = line[:len(line)-len(stripped)]
            out.append(leading_ws + stripped[len("return "):])
        else:
            out.append(line)
        if brace_depth <= 0:
            inside_preview = False
        continue

    out.append(line)

with open(path, "w") as f:
    f.write("\n".join(out) + ("\n" if not out[-1].endswith("\n") else ""))
PY
else
  echo "ℹ️  $FILE not found; skipping SignInView preview patch."
fi

git add "$VIEWS_DIR/ProjectsHomeView.swift" "$VIEWS_DIR/SettingsView.swift" || true
if [[ -f "$VIEWS_DIR/SignInView.swift" ]]; then git add "$VIEWS_DIR/SignInView.swift"; fi

git commit -m "Phase 3 – Step 1c: Fix previews (remove 'return'); Settings uses Org(name:) only; robust join-code display/search; Projects preview compile fix."
git push origin main || echo "⚠️  git push failed (no remote/auth). Local commit created."

echo "✅ Build fixes applied. Open ProjectsHomeView, SettingsView, and SignInView in Canvas."
