#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from folder with .xcodeproj"; exit 1; }

VIEWS="$APP/Views"
mkdir -p "$VIEWS"

# 0) Add a tiny seeding helper used only in previews
cat >"$VIEWS/PreviewSeed.swift" <<'SWIFT'
import SwiftUI
import SwiftData

/// Helper for previews: builds an in-memory ModelContainer and lets you seed data.
enum PreviewSeed {
    static func container(
        _ types: [any PersistentModel.Type],
        seed: (ModelContext) -> Void = { _ in }
    ) -> ModelContainer {
        let schema = Schema(types)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)
        seed(ctx)
        return container
    }
}
SWIFT

# 1) Strip any existing #Preview blocks (clean slate)
clean() { perl -0777 -pe 's/#Preview[^\{]*\{.*?\}\n//sg' -i '' "$1"; }

for f in "$APP/ContentView.swift" "$VIEWS/ContentView.swift" "$VIEWS/ProjectsHomeView.swift" "$VIEWS/SettingsView.swift"; do
  [[ -f "$f" ]] && clean "$f" || true
done

# 2) Add safe seeded previews back

# ContentView (wherever it lives)
for f in "$APP/ContentView.swift" "$VIEWS/ContentView.swift"; do
  [[ -f "$f" ]] || continue
  cat >>"$f" <<'SWIFT'

#Preview("Seeded App Flow") {
    ContentView()
        .modelContainer(
            PreviewSeed.container([Org.self, Item.self]) { ctx in
                ctx.insert(Org(name: "Daliant Lighting"))
                ctx.insert(Item(title: "Smith Residence"))
                ctx.insert(Item(title: "Beach House"))
            }
        )
}
SWIFT
done

# ProjectsHomeView
if [[ -f "$VIEWS/ProjectsHomeView.swift" ]]; then
cat >>"$VIEWS/ProjectsHomeView.swift" <<'SWIFT'

#Preview("Seeded ProjectsHome") {
    NavigationStack { ProjectsHomeView() }
        .modelContainer(
            PreviewSeed.container([Item.self]) { ctx in
                ctx.insert(Item(title: "Smith Residence"))
                ctx.insert(Item(title: "Beach House"))
                ctx.insert(Item(title: "Penthouse Commissioning"))
            }
        )
}
SWIFT
fi

# SettingsView
if [[ -f "$VIEWS/SettingsView.swift" ]]; then
cat >>"$VIEWS/SettingsView.swift" <<'SWIFT'

#Preview("Seeded Settings") {
    NavigationStack { SettingsView() }
        .modelContainer(
            PreviewSeed.container([Org.self]) { ctx in
                ctx.insert(Org(name: "Daliant Lighting"))
            }
        )
}
SWIFT
fi

# 3) Safety pass: ensure key-paths aren't double-escaped
for f in "$APP"/*.swift "$VIEWS"/*.swift; do
  [[ -f "$f" ]] || continue
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f"
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f"
done

# 4) Commit if in git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Previews: add PreviewSeed helper and seeded #Preview blocks"
  git push || true
fi

echo "✅ Seeded previews fixed. In Xcode: Shift⌘K (Clean) → ⌘B (Build), then open Canvas."

