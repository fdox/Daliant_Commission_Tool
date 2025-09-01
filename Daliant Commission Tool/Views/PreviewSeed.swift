import SwiftUI
import SwiftData

/// Helper for previews: builds an in-memory ModelContainer and lets you seed data.
enum PreviewSeed {
    static func container(
        _ types: [any PersistentModel.Type],
        seed: (ModelContext) -> Void = { _ in }
    ) -> ModelContainer {
        let schema = Schema(types)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)
        seed(ctx)
        return container
    }
}