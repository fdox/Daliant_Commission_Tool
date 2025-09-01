#!/usr/bin/env bash
# ---- Patch script: Fix SortDescriptor keypaths + remove 'return' in previews ----
# Save as: patch_previews.sh, then run: bash patch_previews.sh

set -euo pipefail

PROJ_NAME="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
if [[ -z "${PROJ_NAME}" ]]; then
  echo "❌ No .xcodeproj found here. Run this from your app folder." >&2
  exit 1
fi

SRCDIR="$PROJ_NAME/Views"

# Ensure directory exists
mkdir -p "$SRCDIR"

# Apply fixes to all Swift files in Views
for f in "$SRCDIR"/*.swift; do
  [[ -f "$f" ]] || continue
  # Fix double-escaped key paths
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f"
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f"
  # Remove explicit 'return ' inside Previews
  sed -i '' 's/^ *return \(.*#Preview.*\)/\1/' "$f"
  sed -i '' 's/^ *return /    /' "$f"
done

# Git commit if repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Patch: fix SortDescriptor keypaths + remove return in Previews"
  git push || true
fi

echo "✅ Patch applied. Clean (Shift⌘K) and Build (⌘B) in Xcode."

