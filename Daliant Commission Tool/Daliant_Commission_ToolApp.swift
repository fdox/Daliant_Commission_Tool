import SwiftUI
import SwiftData

@main
struct Daliant_Commission_ToolApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Force SwiftData to use a LOCAL store (no SwiftData↔CloudKit mirroring).
    // If file-backed creation fails in dev (e.g., old incompatible store),
    // we fall back to an in-memory store so the app still launches.
    private static func makeLocalContainer() -> ModelContainer {
        let schema = Schema([Org.self, Item.self, Fixture.self])

        // ⬅️ the key line: explicitly disable CloudKit mirroring for SwiftData
        let local = ModelConfiguration(cloudKitDatabase: .none)

        if let c = try? ModelContainer(for: schema, configurations: local) {
            return c
        } else {
            let mem = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: mem)
        }
    }

    private let appContainer: ModelContainer = makeLocalContainer()

    var body: some Scene {
        WindowGroup { AuthGateView() }
            .modelContainer(appContainer)
    }
}
