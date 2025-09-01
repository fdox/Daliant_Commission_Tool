import SwiftUI
import SwiftData

@main
struct Daliant_Commission_ToolApp: App {
    // If you build the container here:
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedContainer)
        }
    }
}

@MainActor
let sharedContainer: ModelContainer = {
    // IMPORTANT: include Fixture.self in the schema
    let schema = Schema([Org.self, Item.self, Fixture.self])
    let config = ModelConfiguration() // adjust if you have custom options
    return try! ModelContainer(for: schema, configurations: config)
}()
