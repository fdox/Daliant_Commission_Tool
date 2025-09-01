#!/usr/bin/env bash
# Daliant Commission Tool — Restore Step 0
# Recreates the minimal SwiftUI + SwiftData scaffold we had working (Org + Projects list + simple sign-in stub),
# without touching your Xcode project file. Run from the folder that contains your .xcodeproj.
# After running, open Xcode and build. If any files show gray in the Project navigator, right‑click the folder and
# "Add Files to…" to re-link them.

set -euo pipefail

# Detect app source directory from .xcodeproj name (spaces allowed)
PROJ_NAME="$(ls -d *.xcodeproj 2>/dev/null | head -n1 | sed 's/.xcodeproj$//')"
if [[ -z "${PROJ_NAME}" ]]; then
  echo "❌ Couldn't find an .xcodeproj here. Open Xcode, create a new iOS App named 'Daliant Commission Tool' (SwiftUI, SwiftData checked), close Xcode, then re-run this script from that folder." >&2
  exit 1
fi

SRCDIR="$PROJ_NAME"
mkdir -p "$SRCDIR/Models" "$SRCDIR/Views" "$SRCDIR/PreviewContent"

# ------------------------- App root -------------------------
cat >"$SRCDIR/${PROJ_NAME// /_}App.swift" <<'SWIFT'
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

# ------------------------- Models -------------------------
cat >"$SRCDIR/Models/Org.swift" <<'SWIFT'
import Foundation
import SwiftData

@Model
final class Org {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
    }
}
SWIFT

cat >"$SRCDIR/Models/Item.swift" <<'SWIFT'
import Foundation
import SwiftData

/// Keep using `Item` as the Project model for now (to avoid Xcode project file edits)
@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date

    init(title: String, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}
SWIFT

# ------------------------- Views -------------------------
cat >"$SRCDIR/Views/ContentView.swift" <<'SWIFT'
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(of: Org.self, sort: .createdAt) private var orgs: [Org]
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

#Preview("App Flow (seeded)") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, Item.self, configurations: config)
    let ctx = ModelContext(container)
    // Seed an org and a couple of projects for preview
    ctx.insert(Org(name: "Daliant Lighting"))
    ctx.insert(Item(title: "Smith Residence"))
    ctx.insert(Item(title: "Beach House"))
    return ContentView()
        .modelContainer(container)
}
SWIFT

cat >"$SRCDIR/Views/SignInView.swift" <<'SWIFT'
import SwiftUI

struct SignInView: View {
    var onSignedIn: (_ userId: String, _ displayName: String?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 56))
            Text("Daliant Commission Tool")
                .font(.title.bold())
            Text("Sign in placeholder — taps 'Continue' to proceed.")
                .foregroundStyle(.secondary)
            Button(action: { onSignedIn(UUID().uuidString, "Tester") }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview { SignInView { _,_ in } }
SWIFT

cat >"$SRCDIR/Views/OrgOnboardingView.swift" <<'SWIFT'
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
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    context.insert(Org(name: name.trimmingCharacters(in: .whitespaces)))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Welcome")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, configurations: config)
    return NavigationStack { OrgOnboardingView() }
        .modelContainer(container)
}
SWIFT

cat >"$SRCDIR/Views/ProjectsHomeView.swift" <<'SWIFT'
import SwiftUI
import SwiftData

struct ProjectsHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(of: Item.self, sort: .createdAt) private var projects: [Item]
    @State private var newTitle: String = ""

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
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Image(systemName: "gearshape") } }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Item.self, configurations: config)
    let ctx = ModelContext(container)
    ctx.insert(Item(title: "Sample A"))
    ctx.insert(Item(title: "Sample B"))
    return NavigationStack { ProjectsHomeView() }
        .modelContainer(container)
}
SWIFT

# ------------------------- (Optional) AppIcon placeholder -------------------------
mkdir -p "$SRCDIR/Assets.xcassets/AppLogo.imageset"
cat > "$SRCDIR/Assets.xcassets/AppLogo.imageset/Contents.json" <<'JSON'
{
  "images" : [
    {"idiom" : "universal", "filename" : "AppLogo.pdf", "scale" : "1x"}
  ],
  "info" : {"author" : "xcode", "version" : 1}
}
JSON

# Tiny 1x1 PDF placeholder (base64)
base64 -d >"$SRCDIR/Assets.xcassets/AppLogo.imageset/AppLogo.pdf" <<'B64'
JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PAovVHlwZSAvQ2F0YWxvZwovUGFnZXMgMiAwIFIKPj4KZW5kb2JqCjIgMCBvYmoKPDwKL1R5cGUgL1BhZ2VzCi9Db3VudCAxCi9LaWRzIFszIDAgUl0KPj4KZW5kb2JqCjMgMCBvYmoKPDwKL1R5cGUgL1BhZ2UKL1BhcmVudCAyIDAgUgovTWVkaWFCb3ggWzAgMCAxIDEgXQovQ29udGVudHMgNCAwIFIKPj4KZW5kb2JqCjQgMCBvYmoKPDwKL0xlbmd0aCAzNwo+PgpzdHJlYW0KQlQKL0RGIDAgc2V0cmdibAowIDAgMCAxIHJnCjAgMCAxIDAgcmUKMCAwIDEgcmUKU1QKZW5kc3RyZWFtCmVuZG9iagp4cmVmCjAgNQowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAxMTMgMDAwMDAgbiAKMDAwMDAwMDA1NSAwMDAwMCBuIAowMDAwMDAwMTk1IDAwMDAwIG4gCjAwMDAwMDAzMDkgMDAwMDAgbiAKdHJhaWxlcgo8PAovUm9vdCAxIDAgUgovU2l6ZSA1Cj4+CiUlRU9G
B64

# ------------------------- Git commit (if repo present) -------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add -A
  git commit -m "Restore Step 0: minimal Org + Projects scaffold with SwiftData + previews"
  git push || true
fi

echo "\n✅ Restore Step 0 complete for project: $PROJ_NAME\nOpen $PROJ_NAME.xcodeproj and Build & Run."

