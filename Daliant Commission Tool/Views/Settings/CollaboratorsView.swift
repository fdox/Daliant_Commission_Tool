//
//  CollaboratorsView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import SwiftUI
import SwiftData
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct CollaboratorsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var orgs: [Org]
    @State private var showingInviteView = false
    @State private var ownerName = ""
    @State private var ownerEmail = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OWNER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        if let org = orgs.first {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ownerName.isEmpty ? "Owner" : ownerName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                if let businessName = org.businessName, !businessName.isEmpty {
                                    Text(businessName)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text(ownerEmail.isEmpty ? "Email not available" : ownerEmail)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Manage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Add, view, or edit roles for \(orgs.first?.businessName ?? "Organization")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COLLABORATORS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            showingInviteView = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                    .font(.caption)
                                Text("Invite Others")
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        
                        // TODO: List of collaborators will go here
                        Text("No collaborators yet")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                } header: {
                    EmptyView()
                }
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInviteView) {
                InviteCollaboratorsView()
            }
            .task {
                loadUserData()
            }
        }
    }
    
    private func loadUserData() {
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            ownerName = user.displayName ?? ""
            ownerEmail = user.email ?? ""
        }
        #endif
    }
}

#if DEBUG
#Preview("Collaborators") {
    let container = try! ModelContainer(for: Org.self, Item.self, Fixture.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Seed with test data
    let context = container.mainContext
    let testOrg = Org(name: "Daliant Test Org")
    testOrg.businessName = "Test Business"
    context.insert(testOrg)
    try? context.save()
    
    return CollaboratorsView()
        .modelContainer(container)
}
#endif
