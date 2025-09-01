#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from the folder with your .xcodeproj"; exit 1; }

VIEWS="$APP/Views"
mkdir -p "$VIEWS"

cat > "$VIEWS/ProjectsHomeView.swift" <<'SWIFT'
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

// MARK: - Preview (safe, seeded)
#Preview("Seeded ProjectsHome") {
    NavigationStack { ProjectsHomeView() }
        .modelContainer({
            let schema = Schema([Item.self])
            let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: [cfg])
            let ctx = ModelContext(container)
            ctx.insert(Item(title: "Smith Residence"))
            ctx.insert(Item(title: "Beach House"))
            ctx.insert(Item(title: "Penthouse Commissioning"))
            return container
        }())
}
SWIFT

# Commit if git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add "$VIEWS/ProjectsHomeView.swift"
  git commit -m "Fix: clean ProjectsHomeView with safe seeded preview"
  git push || true
fi

echo "✅ ProjectsHomeView.swift replaced. Open Xcode → Shift⌘K → ⌘B."
