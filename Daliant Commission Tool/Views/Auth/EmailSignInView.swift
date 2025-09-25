//
//  EmailSignInView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/21/25.
//

import SwiftUI

struct EmailSignInView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool
    var onNext: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.xs) {
                Text("Sign in with Email")
                    .font(DS.Font.title)
                    .foregroundStyle(.primary)
                Text("Enter your email to continue.")
                    .font(DS.Font.sub)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, DS.Spacing.xl + DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.xl)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your email")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                ZStack(alignment: .leading) {
                    if email.isEmpty {
                        Text(verbatim: "example@mail.com")
                            .foregroundStyle(.secondary)          // gray overlay placeholder
                            .padding(.horizontal, 16)
                    }
                    TextField("", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isFocused)
                        .padding(12)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? .black : .gray.opacity(0.3), lineWidth: 1)
                )
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, DS.Spacing.xl)
            }
            
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
            }
        }
        .safeAreaInset(edge: .bottom) {
            DSUI.StickyCtaBar(
                title: isLoading ? "Checking..." : "Next",
                isEnabled: isValidEmail(email) && !isLoading,
                useBackground: false,
                tint: .black
            ) {
                Task {
                    await checkEmailAndProceed()
                }
            }
        }
        .onAppear { isFocused = true }
        .navigationBarBackButtonHidden(false)
    }

    private func checkEmailAndProceed() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmedEmail) else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let emailInUse = try await AuthService.isEmailInUse(trimmedEmail)
            if emailInUse {
                // Email exists, proceed to password sign-in (no error message)
                onNext(trimmedEmail)
            } else {
                // Email doesn't exist, show message and DON'T proceed
                errorMessage = "No account found with this email. Please check your email or create a new account."
                // Do NOT call onNext() - stay on this view
            }
        } catch {
            errorMessage = "Unable to check email. Please try again."
        }
        
        isLoading = false
    }
    
    private func isValidEmail(_ s: String) -> Bool {
        let s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.contains("@") && s.contains(".") && s.count >= 5
    }
}

#Preview {
    NavigationStack {
        EmailSignInView { _ in }
    }
}
