#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from folder with .xcodeproj"; exit 1; }

VIEWS="$APP/Views"
mkdir -p "$VIEWS"

# Helper: replace any existing #Preview blocks with nothing (clean slate)
clean_previews() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  perl -0777 -pe 's/#Preview[^\{]*\{.*?\}\n//sg' -i '' "$file"
}

# 0) Clean existing previews if any
clean_previews "$APP/ContentView.swift"
clean_previews "$VIEWS/ContentView.swift"
clean_previews "$VIEWS/ProjectsHomeView.swift"
clean_previews "$VIEWS/SettingsView.swift"

# 1) ContentView.swift — minimal seeded preview (works whether at root or in Views/)
for f in "$APP/ContentView.swift" "$VIEWS/ContentView.swift"; do
  [[ -f "$f" ]] || continue
  cat >>"$f" <<'SWIFT'

#Preview("Seeded App Flow") {
    ContentView()
        .modelContainer(for: [Org.self, Item.self], inMemory: true) { container in
            let ctx = ModelContext(container)
            // Seed data so flow chooses Projects
            ctx.insert(Org(name: "Daliant Lighting"))
            ctx.insert(Item(title: "Smith Residence"))
            ctx.insert(Item(title: "Beach House"))
        }
}
SWIFT
done

# 2) ProjectsHomeView.swift — seeded preview
if [[ -f "$VIEWS/ProjectsHomeView.swift" ]]; then
cat >>"$VIEWS/ProjectsHomeView.swift" <<'SWIFT'

#Preview("Seeded ProjectsHome") {
    NavigationStack {
        ProjectsHomeView()
    }
    .modelContainer(for: [Item.self], inMemory: true) { container in
        let ctx = ModelContext(container)
        ctx.insert(Item(title: "Smith Residence"))
        ctx.insert(Item(title: "Beach House"))
        ctx.insert(Item(title: "Penthouse Commissioning"))
    }
}
SWIFT
fi

# 3) SettingsView.swift — seeded preview
if [[ -f "$VIEWS/SettingsView.swift" ]]; then
cat >>"$VIEWS/SettingsView.swift" <<'SWIFT'

#Preview("Seeded Settings") {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Org.self], inMemory: true) { container in
        let ctx = ModelContext(container)
        ctx.insert(Org(name: "Daliant Lighting"))
    }
}
SWIFT
fi

# Ensure key-paths are correctly escaped (safety pass)
for f in "$APP"/*.swift "$VIEWS"/*.swift; do
  [[ -f "$f" ]] || continue
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f"
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f"
done

# Commit if in git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Add: safe seeded #Preview blocks for ContentView, ProjectsHomeView, SettingsView"
  git push || true
fi

echo "✅ Seeded previews added. In Xcode: open Canvas, or Shift⌘K then ⌘B."

