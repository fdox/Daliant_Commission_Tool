#!/usr/bin/env bash
set -euo pipefail

APP="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
[[ -n "$APP" ]] || { echo "❌ Run from folder with .xcodeproj"; exit 1; }

SRC="$APP"
VIEWS="$APP/Views"
MODELS="$APP/Models"
mkdir -p "$SRC" "$VIEWS" "$MODELS"

# ---- App root (no previews) ----
cat >"$SRC/${APP// /_}App.swift" <<'SWIFT'
import SwiftUI
import SwiftData

@main
struct Daliant_Commission_ToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - SwiftData Container
let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Org.self,
        Item.self
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try! ModelContainer(for: schema, configurations: [config])
}()
SWIFT

# ---- ContentView (no previews) ----
cat >"$VIEWS/ContentView.swift" <<'SWIFT'
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Org.createdAt, order: .forward)]) private var orgs: [Org]
    @AppStorage("signedInUserID") private var signedInUserID: String = ""

    var body: some View {
        NavigationStack {
            if signedInUserID.isEmpty {
                SignInView { userId, _ in
                    signedInUserID = userId
                }
            } else if orgs.isEmpty {
                OrgOnboardingView()
            } else {
                ProjectsHomeView()
            }
        }
    }
}
SWIFT

# ---- OrgOnboardingView (no previews) ----
cat >"$VIEWS/OrgOnboardingView.swift" <<'SWIFT'
import SwiftUI
import SwiftData

struct OrgOnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var name: String = ""

    var body: some View {
        Form {
            Section("Organization") {
                TextField("Organization name", text: $name)
            }
            Section {
                Button("Create Organization") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    context.insert(Org(name: trimmed))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Welcome")
    }
}
SWIFT

# ---- Safety: remove ALL #Preview blocks across project ----
shopt -s nullglob
for f in "$APP"/*.swift "$VIEWS"/*.swift "$MODELS"/*.swift; do
  perl -0777 -pe 's/#Preview[^\{]*\{(?:[^{}]++|(?0))*\}\s*//sg' -i '' "$f"
done

# ---- Safety: fix any double-escaped keypaths ----
for f in "$APP"/*.swift "$VIEWS"/*.swift "$MODELS"/*.swift; do
  sed -i '' 's/\\\\Item.createdAt/\\Item.createdAt/g' "$f" 2>/dev/null || true
  sed -i '' 's/\\\\Org.createdAt/\\Org.createdAt/g' "$f" 2>/dev/null || true
done

# ---- Git commit if repo ----
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Reset: App, ContentView, OrgOnboarding (no previews) + keypath fixes"
  git push || true
fi

echo "✅ Core files reset. In Xcode: Shift⌘K (Clean) → ⌘B (Build)."

