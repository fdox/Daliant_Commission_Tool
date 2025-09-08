//
//  ActiveOrgPickerView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/4/25.
//

import SwiftUI
import SwiftData

struct ActiveOrgPickerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Org.name) private var orgs: [Org]
    @State private var selection: UUID?

    var body: some View {
        List {
            ForEach(orgs) { org in
                Button {
                    ActiveOrgStore.shared.setActiveOrgID(org.id)
                    selection = org.id
                } label: {
                    HStack {
                        Text(org.name)
                        Spacer()
                        if org.id == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Active Org")
        .onAppear {
            ActiveOrgStore.shared.ensureDefault(in: context)
            selection = ActiveOrgStore.shared.activeOrg(in: context)?.id
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Org.self, configurations: config)
    let ctx = container.mainContext
    ctx.insert(Org(name: "Org A"))
    ctx.insert(Org(name: "Org B"))
    return NavigationStack { ActiveOrgPickerView() }.modelContainer(container)
}
