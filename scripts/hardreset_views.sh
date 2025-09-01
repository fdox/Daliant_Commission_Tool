#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from folder with .xcodeproj"; exit 1; }

VIEWS="$APP/Views"
mkdir -p "$VIEWS"

# 1) ProjectsHomeView.swift (clean, no #Preview)
cat >"$VIEWS/ProjectsHomeView.swift" <<'SWIFT'
import SwiftUI
import SwiftData

struct ProjectsHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Item.createdAt, order: .forward)]) private var projects: [Item]
    @State private var newTitle: String = ""
    @State private var showSettings = false

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New project name", text: $newTitle)
                    Button("Add") {
                        let t = newTitle.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        context.insert(Item(title: t))
                        newTitle = ""
                    }
                }
            }
            Section {
                ForEach(projects) { p in
                    NavigationLink(value: p.id) {
                        VStack(alignment: .leading) {
                            Text(p.title)
                            Text(p.createdAt, style: .date)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { context.delete(projects[i]) }
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
    }
}
SWIFT

# 2) SettingsView.swift (clean, no #Preview)
cat >"$VIEWS/SettingsView.swift" <<'SWIFT'
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("signedInUserID") private var signedInUserID: String = ""
    @Query(sort: [SortDescriptor(\Org.createdAt, order: .forward)]) private var orgs: [Org]

    @State private var name: String = ""
    @State private var showDeleteAlert = false

    var body: some View {
        Form {
            if let org = orgs.first {
                Section("Organization") {
                    TextField("Organization name", text: $name)
                        .onAppear { name = org.name }
                    Button("Save Name") {
                        let newName = name.trimmingCharacters(in: .whitespaces)
                        if !newName.isEmpty, newName != org.name { org.name = newName }
                    }
                }
                Section {
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Text("Delete Organization")
                    }
                }
            } else {
                Section {
                    Text("No organization found. Create one to continue.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Account") {
                Button("Sign Out", role: .destructive) {
                    signedInUserID = ""
                    dismiss()
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
        .alert("Delete Organization?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let org = orgs.first { context.delete(org); try? context.save() }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes your org from this device’s data store.")
        }
    }
}
SWIFT

# 3) (Optional) Remove previews from ContentView too to be extra safe
if [[ -f "$VIEWS/ContentView.swift" ]]; then
  perl -0777 -pe 's/#Preview[^\{]*\{.*?\}\n//s' -i '' "$VIEWS/ContentView.swift"
fi
if [[ -f "$APP/ContentView.swift" ]]; then
  perl -0777 -pe 's/#Preview[^\{]*\{.*?\}\n//s' -i '' "$APP/ContentView.swift"
fi

# 4) Ensure key-paths aren’t double-escaped
for f in "$APP"/*.swift "$VIEWS"/*.swift; do
  [[ -f "$f" ]] || continue
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f"
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f"
done

# Commit if repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Hard reset: ProjectsHomeView & SettingsView (no previews), fix key-paths"
  git push || true
fi

echo "✅ Views reset. In Xcode: Shift⌘K (Clean) → ⌘B (Build)."

