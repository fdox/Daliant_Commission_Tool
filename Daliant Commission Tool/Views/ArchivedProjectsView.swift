//
//  ArchivedProjectsView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/6/25.
//

import SwiftUI
import SwiftData
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct ArchivedProjectsView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Item> { $0.archivedAt != nil },
        sort: [SortDescriptor(\Item.archivedAt, order: .reverse)]
    ) private var archived: [Item]

    var body: some View {
        List {
            if archived.isEmpty {
                ContentUnavailableView("No archived projects", systemImage: "archivebox")
            } else {
                ForEach(archived) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            if let a = item.archivedAt {
                                Text(a.formatted()).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .leading) {
                        Button("Restore") { restore(item) }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            purge(item)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
        }
        .navigationTitle("Archived Projects")
    }

    // MARK: Actions

    private func restore(_ item: Item) {
        item.archivedAt = nil
        AutosaveCenter.shared.touch(item, context: context)
        Task { @MainActor in
            do { try await ProjectSyncService.shared.push(item, context: context) }
            catch { print("[Archive] restore push error: \(error)") }
        }
    }

    private func purge(_ item: Item) {
        Task { @MainActor in
            do {
                try await ProjectSyncService.shared.delete(item, context: context)
            } catch {
                print("[Archive] purge error: \(error)")
            }
        }
    }
}
