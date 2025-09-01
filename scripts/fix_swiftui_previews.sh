#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from folder with .xcodeproj"; exit 1; }

VIEWS="$APP/Views"

# 0) Global key-path unescape in all Swift files (root + Views)
for f in "$APP"/*.swift "$VIEWS"/*.swift 2>/dev/null; do
  [[ -f "$f" ]] || continue
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f"
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f"
done

# 1) ContentView.swift – replace only the #Preview block with a minimal one
perl -0777 -pe '
  s/#Preview[^\{]*\{.*?\}\n/#Preview {\n    ContentView()\n        .modelContainer(for: [Org.self, Item.self], inMemory: true)\n}\n/s
' -i '' "$APP/Views/ContentView.swift" 2>/dev/null || true
# Some templates place ContentView.swift at root; patch there too:
perl -0777 -pe '
  s/#Preview[^\{]*\{.*?\}\n/#Preview {\n    ContentView()\n        .modelContainer(for: [Org.self, Item.self], inMemory: true)\n}\n/s
' -i '' "$APP/ContentView.swift" 2>/dev/null || true

# 2) ProjectsHomeView.swift – replace preview
if [[ -f "$VIEWS/ProjectsHomeView.swift" ]]; then
  perl -0777 -pe '
    s/#Preview[^\{]*\{.*?\}\n/#Preview {\n    NavigationStack { ProjectsHomeView() }\n        .modelContainer(for: [Item.self], inMemory: true)\n}\n/s
  ' -i '' "$VIEWS/ProjectsHomeView.swift"
fi

# 3) SettingsView.swift – replace preview
if [[ -f "$VIEWS/SettingsView.swift" ]]; then
  perl -0777 -pe '
    s/#Preview[^\{]*\{.*?\}\n/#Preview {\n    NavigationStack { SettingsView() }\n        .modelContainer(for: [Org.self], inMemory: true)\n}\n/s
  ' -i '' "$VIEWS/SettingsView.swift"
fi

# Git commit if repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Fix: minimal SwiftUI #Preview blocks + key-path unescape"
  git push || true
fi

echo "✅ Fixed previews + key-paths. In Xcode: Shift⌘K (Clean) → ⌘B (Build)."

