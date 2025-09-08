//
//  ActiveOrgStore.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/4/25.
//

import Foundation
import SwiftData

@MainActor
final class ActiveOrgStore: ObservableObject {
    static let shared = ActiveOrgStore()

    private let defaultsKey = "ActiveOrgID"
    @Published private(set) var activeOrgID: UUID?

    private init() {
        if let s = UserDefaults.standard.string(forKey: defaultsKey),
           let id = UUID(uuidString: s) {
            self.activeOrgID = id
        }
    }

    func setActiveOrgID(_ id: UUID?) {
        activeOrgID = id
        if let id {
            UserDefaults.standard.set(id.uuidString.lowercased(), forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    func ensureDefault(in context: ModelContext) {
        // If no selection yet, or selected org no longer exists, pick first available.
        let all = (try? context.fetch(FetchDescriptor<Org>())) ?? []
        if let id = activeOrgID, all.contains(where: { $0.id == id }) {
            return
        }
        setActiveOrgID(all.first?.id) // may set nil if there are no orgs yet
    }

    func activeOrg(in context: ModelContext) -> Org? {
        guard let id = activeOrgID else { return (try? context.fetch(FetchDescriptor<Org>()))?.first }
        return try? context.fetch(FetchDescriptor<Org>()).first(where: { $0.id == id })
    }

    func activeOrgName(in context: ModelContext) -> String {
        activeOrg(in: context)?.name ?? "—"
    }
}
