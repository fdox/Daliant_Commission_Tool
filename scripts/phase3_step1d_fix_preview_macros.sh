#!/usr/bin/env bash
set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "❌ Run this from within your Git repository."
  exit 1
}

# Locate Views folder
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

############################################
# ProjectsHomeView.swift (preview = single expression)
############################################
cat > "$VIEWS_DIR/ProjectsHomeView.swift" <<'SWIFT'
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
                    Button { showingSettings = true } label: {
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
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { projectName($0).localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Safe accessors
    private func projectName(_ item: Item) -> String {
        if let n = Mirror(reflecting: item).children.first(where: { $0.label == "name" })?.value as? String, !n.isEmpty { return n }
        if let t = Mirror(reflecting: item).children.first(where: { $0.label == "title" })?.value as? String, !t.isEmpty { return t }
        return "Untitled"
    }
    private func projectControlSystemTag(_ item: Item) -> String? {
        if let raw = Mirror(reflecting: item).children.first(where: { $0.label == "controlSystemRaw" })?.value as? String, !raw.isEmpty {
            return prettyControlSystem(raw)
        }
        if let enumVal = Mirror(reflecting: item).children.first(where: { $0.label == "controlSystem" })?.value {
            return prettyControlSystem(String(describing: enumVal))
        }
        return nil
    }
    private func projectContact(_ item: Item) -> String? {
        let m = Mirror(reflecting: item)
        let f = m.children.first(where: { $0.label == "contactFirstName" })?.value as? String
        let l = m.children.first(where: { $0.label == "contactLastName" })?.value as? String
        let full = [f, l].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
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
            Text(name).font(.headline).lineLimit(1)
            HStack(spacing: 8) {
                if let tag = controlSystemTag {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .accessibilityLabel("Control system \(tag)")
                }
                if let contact {
                    Text(contact).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
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

// MARK: - Preview helper: do seeding OUTSIDE the #Preview result builder
fileprivate enum PreviewFactory {
    static func projectsHome() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
        let context = container.mainContext

        let org = Org(name: "Dox Electronics") // (no joinCode init in your model)
        context.insert(org)

        let p1 = Item(name: "Smith Residence")
        let p2 = Item(name: "Beach House")
        context.insert(p1)
        context.insert(p2)
        _ = try? context.save()

        return ProjectsHomeView().modelContainer(container)
    }
}

#Preview("Projects — Seeded") {
    PreviewFactory.projectsHome()
}
SWIFT

############################################
# SettingsView.swift (preview = single expression)
############################################
cat > "$VIEWS_DIR/SettingsView.swift" <<'SWIFT'
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
                    Text(currentOrgName()).fontWeight(.semibold)
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
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK", role: .cancel) { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    // MARK: Helpers
    private func currentOrgName() -> String {
        guard let org = currentOrg else { return "—" }
        if let n = Mirror(reflecting: org).children.first(where: { $0.label == "name" })?.value as? String, !n.isEmpty { return n }
        return "—"
    }
    private func currentOrgJoinCode() -> String {
        guard let org = currentOrg else { return "—" }
        let m = Mirror(reflecting: org)
        if let c = m.children.first(where: { $0.label == "joinCode" })?.value as? String, !c.isEmpty { return c }
        if let c = m.children.first(where: { $0.label == "code" })?.value as? String, !c.isEmpty { return c }
        if let name = m.children.first(where: { $0.label == "name" })?.value as? String,
           let parsed = parseCodeFromName(name) { return parsed }
        return "—"
    }
    private func parseCodeFromName(_ name: String) -> String? {
        guard let open = name.lastIndex(of: "("),
              let close = name.lastIndex(of: ")"),
              close > open else { return nil }
        let code = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }
    private func joinDifferentOrg() {
        let code = newJoinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        do {
            let all = try context.fetch(FetchDescriptor<Org>())
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
                newJoinCode = ""; return
            }
            for o in all { context.delete(o) }
            let newOrg = Org(name: "Org (\(code))") // fallback: encode code into name
            context.insert(newOrg)
            try context.save()
            newJoinCode = ""
        } catch {
            errorMessage = "Could not switch org: \(error.localizedDescription)"
        }
    }
    private func signOut() {
        do {
            for o in try context.fetch(FetchDescriptor<Org>()) { context.delete(o) }
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}

// Preview helper (single expression in #Preview)
fileprivate enum SettingsPreviewFactory {
    static func seeded() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
        let context = container.mainContext
        let org = Org(name: "Dox Electronics") // (no joinCode init in your model)
        context.insert(org)
        _ = try? context.save()
        return NavigationStack { SettingsView() }.modelContainer(container)
    }
}

#Preview("Settings — Seeded") {
    SettingsPreviewFactory.seeded()
}
SWIFT

############################################
# Remove 'return ' inside #Preview blocks across all Views/*.swift
############################################
find "$VIEWS_DIR" -name "*.swift" -print0 | while IFS= read -r -d '' f; do
  /usr/bin/python3 <<PY
import os, re
path = r"""$f"""
with open(path, "r") as fh:
    src = fh.read()
out = []
inside = False
depth = 0
for line in src.splitlines():
    s = line.lstrip()
    if s.startswith("#Preview"):
        inside = True
        depth = 0
        out.append(line); continue
    if inside:
        depth += line.count("{") - line.count("}")
        # Strip leading 'return ' ONLY when inside a preview closure
        if s.startswith("return "):
            out.append(line[:len(line)-len(s)] + s[len("return "):])
        else:
            out.append(line)
        if depth <= 0:
            inside = False
        continue
    out.append(line)
with open(path, "w") as fh:
    fh.write("\n".join(out) + ("\n" if not src.endswith("\n") else ""))
PY
done

git add "$VIEWS_DIR/ProjectsHomeView.swift" "$VIEWS_DIR/SettingsView.swift" "$VIEWS_DIR"/*.swift
git commit -m "Phase 3 – Step 1d: Fix #Preview macros (single-expression previews), remove 'return' inside previews, keep Org(name:) seeding."
git push origin main || echo "⚠️  git push failed (no remote/auth). Local commit created."

echo "✅ Preview fixes applied. Open ProjectsHomeView, SettingsView, and SignInView in Canvas."
