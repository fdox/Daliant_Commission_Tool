// PreviewContent/PreviewSupport.swift
// Deterministic in‑memory SwiftData container + seed used ONLY for previews.

import SwiftData
import Foundation

enum PreviewSupport {
    /// Always create a fresh, in‑memory container on the main actor.
    @MainActor
    static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // ⬇️ Remove the brackets; pass types as variadic args
        return try! ModelContainer(
            for: Org.self, Item.self, Fixture.self,
            configurations: config
        )
    }


    /// Seed a sample org/project/fixtures into the given container.
    /// Returns the primary project to drive detail previews.
    @discardableResult
    @MainActor
    static func seed(into container: ModelContainer) -> Item {
        let context = ModelContext(container)

        let org = Org(name: "Daliant Test Org")
        context.insert(org)

        let p1 = Item(title: "Smith Residence")
        p1.createdAt = Date()
        p1.contactFirstName = "Alex"
        p1.contactLastName  = "Smith"
        p1.siteAddress      = "123 Ocean Ave"
        p1.controlSystemRaw = "Lutron QS"
        context.insert(p1)

        // Simple fixtures for p1
        let f1 = Fixture(label: "Kitchen Cans", shortAddress: 3, groups: 1)
        f1.room = "Kitchen"; f1.serial = "SN-001"; f1.dtTypeRaw = "DT8"; f1.project = p1
        context.insert(f1)

        let f2 = Fixture(label: "Dining Pendants", shortAddress: 7, groups: 2)
        f2.room = "Dining"; f2.project = p1
        context.insert(f2)

        try? context.save()
        return p1
    }
}
