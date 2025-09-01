#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from folder with .xcodeproj"; exit 1; }

VIEWS="$APP/Views"

# Make globs expand to nothing instead of literal patterns
shopt -s nullglob

# 0) Global key-path unescape in all Swift files (root + Views)
for f in "$APP"/*.swift "$VIEWS"/*.swift; do
  [[ -f "$f" ]] || continue
  # Fix double-escaped key paths (BSD sed on macOS)
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f"
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f"
done

# 1) ContentView.swift – replace only the #Preview block with a minimal one
if [[ -f "$APP/Views/ContentView.swift" ]]; then
  perl -0777 -pe '
    s/#Preview[^\{]*\{.*?\}\n/#Preview {\n    ContentView()\n        .modelContainer(for: [Org.self, Item.self], inMemory: true)\n}\n/s
  ' -i '' "$APP/Views/ContentView.swift"
fi
# Some templates place ContentView.swift at root; patch there too:
if [[ -f "$APP/ContentView.swift" ]]; then
  perl -0777 -pe '
    s/#Preview[^\{]*\{.*?\}\n/#Preview {\n    ContentView()\n        .modelContainer(for: [Org.self, Item.self], inMemory: true)\n}\n/s
  ' -i '' "$APP/ContentView.swift"
fi

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

