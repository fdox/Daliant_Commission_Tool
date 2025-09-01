#!/usr/bin/env bash
set -euo pipefail
APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')" || true
[[ -n "${APP:-}" ]] || { echo "❌ Run from the folder with your .xcodeproj"; exit 1; }

shopt -s nullglob
FILES=( "$APP"/*.swift "$APP"/Views/*.swift )

# Remove every #Preview { ... } block in all Swift files
for f in "${FILES[@]}"; do
  perl -0777 -pe 's/#Preview[^\{]*\{(?:[^{}]++|(?0))*\}\s*//sg' -i '' "$f"
  # Safety: collapse multiple closing braces that slipped to top level
  sed -i '' 's/^\s*}\s*$//g' "$f"
done

# Commit if git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Chore: remove all #Preview blocks (stabilize build)"
  git push || true
fi
echo "✅ Previews removed. Clean (Shift⌘K) → Build (⌘B)."

