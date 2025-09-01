#!/usr/bin/env bash
set -euo pipefail

# Auto-detect Views folder
if [ -d "Views" ]; then
  VIEWS_DIR="Views"
elif [ -d "Daliant Commission Tool/Views" ]; then
  VIEWS_DIR="Daliant Commission Tool/Views"
elif [ -d "Daliant_Commission_Tool/Views" ]; then
  VIEWS_DIR="Daliant_Commission_Tool/Views"
else
  echo "❌ Could not find a Views folder."
  exit 1
fi

FILE="$VIEWS_DIR/SignInView.swift"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "❌ Run this from within your Git repository."
  exit 1
}

if [[ ! -f "$FILE" ]]; then
  echo "❌ $FILE not found. Adjust the path if your SignInView lives elsewhere."
  exit 1
fi

if grep -q "#Preview" "$FILE"; then
  echo "ℹ️  $FILE already contains a #Preview. No changes made."
  exit 0
fi

cat >> "$FILE" <<'SWIFT'

#if DEBUG
import SwiftData

#Preview("Sign In – Basic") {
    // If SignInView needs a model container, uncomment below:
    /*
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    return SignInView().modelContainer(container)
    */
    return SignInView()
}
#endif
SWIFT

git add "$FILE"
git commit -m "Phase 3 – Add Canvas preview to SignInView (non-destructive append)"
git push origin main || {
  echo "⚠️  git push failed (no remote or auth?). Commit is still created locally."
}
echo "✅ Preview appended to $FILE. Open it in Canvas."
