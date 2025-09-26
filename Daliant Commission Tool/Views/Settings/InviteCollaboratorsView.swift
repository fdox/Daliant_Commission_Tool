//
//  InviteCollaboratorsView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import SwiftUI

struct InviteCollaboratorsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var selectedRole: CollaboratorRole? = nil
    @State private var attemptedSubmit = false
    @FocusState private var emailFocused: Bool
    
    enum CollaboratorRole: String, CaseIterable {
        case admin = "admin"
        case technician = "technician"
        case guest = "guest"
        
        var title: String {
            switch self {
            case .admin: return "Admin"
            case .technician: return "Technician"
            case .guest: return "Guest"
            }
        }
        
        var description: String {
            switch self {
            case .admin: return "Has access to create projects, edit projects, delete projects, invite collaborators and remove collaborators, but can't delete the organization."
            case .technician: return "Can create projects and edit projects."
            case .guest: return "Can view projects but can't delete or edit them."
            }
        }
    }
    
    private var isValidEmail: Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }
    
    private var showEmailError: Bool { 
        attemptedSubmit && !isValidEmail 
    }
    
    private var isFormValid: Bool {
        isValidEmail && selectedRole != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    
                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Text("Invite Collaborators")
                            .font(DS.Font.title)
                        
                        Text("Invite people to collaborate on your projects and assign them roles.")
                            .font(DS.Font.sub)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.lg)
                    .padding(.horizontal, DS.Spacing.xl)
                    
                    // Email Input
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Enter Collaborator Email")
                            .font(DS.Font.heading)
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            TextField("Enter email address", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($emailFocused)
                                .onSubmit {
                                    if isValidEmail {
                                        emailFocused = false
                                    }
                                }
                            
                            if showEmailError {
                                Text("Please enter a valid email address")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    
                    // Separator
                    DSUI.OrDivider(text: "")
                        .padding(.horizontal, DS.Spacing.xl)
                    
                    // Role Selection
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Choose Roles")
                                .font(DS.Font.heading)
                            
                            Text("Select a role for your new collaborator.")
                                .font(DS.Font.sub)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("SYSTEM ROLES")
                            .font(DS.Font.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: DS.Spacing.md) {
                            ForEach(CollaboratorRole.allCases, id: \.self) { role in
                                RoleSelectionRow(
                                    role: role,
                                    isSelected: selectedRole == role,
                                    onTap: {
                                        selectedRole = selectedRole == role ? nil : role
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                }
                
                // Send Invitation Button
                VStack {
                    Button(action: sendInvitation) {
                        Text("Send Invitation")
                            .font(DS.Font.heading)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSUI.PrimaryButtonStyle())
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    .padding(.horizontal, DS.Spacing.xl)
                }
                .padding(.top, DS.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere
                emailFocused = false
            }
        }
    }
    
    private func sendInvitation() {
        attemptedSubmit = true
        
        guard isFormValid else { return }
        
        // TODO: Implement actual invitation sending logic
        print("Sending invitation to \(email) with role \(selectedRole?.rawValue ?? "none")")
        
        // For now, just dismiss
        dismiss()
    }
}

private struct RoleSelectionRow: View {
    let role: InviteCollaboratorsView.CollaboratorRole
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(role.title)
                        .font(DS.Font.heading)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(role.description)
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(
                                isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Invite Collaborators") {
    InviteCollaboratorsView()
}
#endif
