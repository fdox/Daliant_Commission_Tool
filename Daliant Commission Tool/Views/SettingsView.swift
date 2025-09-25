import SwiftUI
import SwiftData
#if canImport(CloudKit)
import CloudKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var orgs: [Org]
    @AppStorage("commissioningMode") private var commissioningMode: CommissioningMode = .simulated

    @State private var errorMessage: String?
    
    // Profile editing state
    @State private var isEditingProfile = false
    @State private var fullName = ""
    @State private var emailAddress = ""
    @State private var phoneNumber = ""
    @State private var isEmailVerified = false
    
    // Business Info editing state
    @State private var isEditingBusinessInfo = false
    @State private var businessName = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""

    var body: some View {
        Form {
            Section("Profile") {
                if isEditingProfile {
                    // Editable fields
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Enter full name", text: $fullName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("Enter email", text: $emailAddress)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                
                                if !isEmailVerified {
                                    Button("Verify") {
                                        Task {
                                            do {
                                                try await AuthState.shared.sendEmailVerification()
                                                errorMessage = "Verification email sent. Please check your inbox."
                                            } catch {
                                                errorMessage = "Failed to send verification email: \(error.localizedDescription)"
                                            }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            if isEmailVerified {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                    Text("Email verified")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone Number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Enter phone number", text: $phoneNumber)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.phonePad)
                        }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isEditingProfile = false
                            loadUserData()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Save") {
                            Task {
                                await saveProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Display mode
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Full Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(fullName.isEmpty ? "Not set" : fullName)
                                .font(.body)
                        }
                        
                        HStack {
                            Text("Email Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(emailAddress.isEmpty ? "Not set" : emailAddress)
                                    .font(.body)
                                if isEmailVerified {
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.green)
                                        Text("Verified")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                } else {
                                    Text("Not verified")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Phone Number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(phoneNumber.isEmpty ? "Not set" : phoneNumber)
                                .font(.body)
                        }
                    }
                    
                    Button("Edit Profile") {
                        isEditingProfile = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section("Business Info") {
                if isEditingBusinessInfo {
                    // Editable business info fields
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Business Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Enter business name", text: $businessName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Address Line 1")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Enter address line 1", text: $addressLine1)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Address Line 2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Enter address line 2 (optional)", text: $addressLine2)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("City")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("City", text: $city)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("State")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("State", text: $state)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ZIP")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("ZIP", text: $zipCode)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isEditingBusinessInfo = false
                            loadBusinessInfo()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Save") {
                            Task {
                                await saveBusinessInfo()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Display mode
                    let org = orgs.first
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Business Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(businessName.isEmpty ? "Not set" : businessName)
                                .font(.body)
                        }
                        
                        if !addressLine1.isEmpty || !city.isEmpty {
                            HStack {
                                Text("Address")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    if !addressLine1.isEmpty {
                                        Text(addressLine1)
                                            .font(.body)
                                    }
                                    if !addressLine2.isEmpty {
                                        Text(addressLine2)
                                            .font(.body)
                                    }
                                    if !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
                                        Text("\(city)\(city.isEmpty ? "" : ", ")\(state) \(zipCode)")
                                            .font(.body)
                                    }
                                }
                            }
                        }
                        
                        if let org = org {
                            HStack {
                                Text("Organization ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(org.id.uuidString.lowercased())
                                    .font(.footnote)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    
                    Button("Edit Business Info") {
                        isEditingBusinessInfo = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section("Roles & Permissions") {
                let org = orgs.first
                let hasOrganization = org != nil && !(org?.businessName?.isEmpty ?? true)
                
                if hasOrganization {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Manage")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Text("Add, view, or edit roles for \(org?.businessName ?? "Organization")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button("Invite Collaborator") {
                            // TODO: Navigate to collaborator invitation view
                            errorMessage = "Collaborator invitation feature coming soon!"
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Organization Required")
                            .font(.headline)
                        
                        Text("Create your business information first to enable team collaboration and role management.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button("Set Up Business Info") {
                            isEditingBusinessInfo = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // Single‑org mode: hide this whole section when multipleOrgsEnabled == false
            if FeatureFlags.multipleOrgsEnabled {
                Section("Active Organization") {
                    LabeledContent("Active") {
                        Text(ActiveOrgStore.shared.activeOrgName(in: context)).bold()
                    }
                    NavigationLink("Switch Active Org…") {
                        ActiveOrgPickerView()
                    }
                }
            }

            // Legacy CloudKit UI fully hidden unless explicitly enabled
            #if canImport(CloudKit)
            if FeatureFlags.cloudKitUIEnabled {
                Section("Account & Cloud (Legacy CK)") {
                    NavigationLink("Account") { AccountView() }
                    NavigationLink("Cloud Sync (10d)") { CloudSyncDebugView() }
                    CloudStatusView(simulatedStatus: nil)
                }
            }
            #endif

            #if DEBUG
            Section("Commissioning") {
                Picker("Mode", selection: $commissioningMode) {
                    ForEach(CommissioningMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("BLE is a stub in 7a; behavior remains simulated until later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            #endif
            Section("Data") {
                NavigationLink("Archived Projects") {
                    ArchivedProjectsView()
                }
            }
            
            // Sign out (Firebase + clear local orgs)
            Section {
                Button(role: .destructive) { signOut() } label: { Text("Sign out") }
            }
        }
        .task {
            ActiveOrgStore.shared.ensureDefault(in: context)
            await UserProfileService.shared.ensureProfile()
            loadUserData()
            loadBusinessInfo()
        }
        .navigationTitle("Account Settings")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: - Helpers
    private func loadUserData() {
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            fullName = user.displayName ?? ""
            emailAddress = user.email ?? ""
            phoneNumber = user.phoneNumber ?? ""
            isEmailVerified = user.isEmailVerified
        }
        #endif
    }
    
    private func saveProfile() async {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            // Update display name if changed
            if user.displayName != fullName {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = fullName
                try await changeRequest.commitChanges()
            }
            
            // Update phone number if changed
            if user.phoneNumber != phoneNumber {
                await UserProfileService.shared.setPhone(phoneNumber.isEmpty ? nil : phoneNumber)
            }
            
            // Reload user to get updated data
            try await AuthState.shared.reloadCurrentUser()
            
            isEditingProfile = false
            loadUserData()
            
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
        }
        #endif
    }
    
    private func loadBusinessInfo() {
        if let org = orgs.first {
            businessName = org.businessName ?? ""
            addressLine1 = org.addressLine1 ?? ""
            addressLine2 = org.addressLine2 ?? ""
            city = org.city ?? ""
            state = org.state ?? ""
            zipCode = org.zipCode ?? ""
        }
    }
    
    private func saveBusinessInfo() async {
        do {
            let org = orgs.first ?? Org(name: businessName.isEmpty ? "Organization" : businessName)
            
            // Update business info
            org.businessName = businessName.isEmpty ? nil : businessName
            org.addressLine1 = addressLine1.isEmpty ? nil : addressLine1
            org.addressLine2 = addressLine2.isEmpty ? nil : addressLine2
            org.city = city.isEmpty ? nil : city
            org.state = state.isEmpty ? nil : state
            org.zipCode = zipCode.isEmpty ? nil : zipCode
            org.updatedAt = Date()
            
            // Set owner UID if not already set
            #if canImport(FirebaseAuth)
            if org.ownerUid == nil, let uid = Auth.auth().currentUser?.uid {
                org.ownerUid = uid
            }
            #endif
            
            // If this is a new org, insert it
            if orgs.isEmpty {
                context.insert(org)
            }
            
            try context.save()
            isEditingBusinessInfo = false
            
        } catch {
            errorMessage = "Failed to save business info: \(error.localizedDescription)"
        }
    }
    
    private func signOut() {
        
        // 11e-2: stop live listeners before tearing down auth/local data
        LiveSyncCenter.shared.stop()
        
        // 1) Firebase sign‑out (safe even if already signed out)
        do { try AuthState.shared.signOut() }
        catch { errorMessage = "Sign out error: \(error.localizedDescription)" }

        // 2) Clear local Orgs and dismiss
        do {
            for o in try context.fetch(FetchDescriptor<Org>()) { context.delete(o) }
            try context.save()
            dismiss()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
#Preview("Settings — Seeded") {
    let container = try! ModelContainer(for: Org.self, Item.self, Fixture.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Seed with test data
    let context = container.mainContext
    let testOrg = Org(name: "Daliant Test Org")
    context.insert(testOrg)
    try? context.save()
    
    return NavigationStack {
        SettingsView()
    }
    .modelContainer(container)
}
#endif
