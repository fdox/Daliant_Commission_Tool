#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from the folder with your .xcodeproj"; exit 1; }

VIEWS="$APP/Views"
mkdir -p "$VIEWS"

# Overwrite SignInView.swift with a clean, no-preview version
cat >"$VIEWS/SignInView.swift" <<'SWIFT'
import SwiftUI

struct SignInView: View {
    var onSignedIn: (_ userId: String, _ displayName: String?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 56))
            Text("Daliant Commission Tool")
                .font(.title.bold())
            Text("Sign in placeholder — tap Continue to proceed.")
                .foregroundStyle(.secondary)
            Button("Continue") {
                onSignedIn(UUID().uuidString, "Tester")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding()
    }
}
SWIFT

# Safety: remove any stray #Preview blocks that might still be present in this file
perl -0777 -pe 's/#Preview[^\{]*\{(?:[^{}]++|(?0))*\}\s*//sg' -i '' "$VIEWS/SignInView.swift"

# Commit if in git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add "$VIEWS/SignInView.swift"
  git commit -m "Reset: clean SignInView (no previews, proper braces)"
  git push || true
fi

echo "✅ SignInView reset."

