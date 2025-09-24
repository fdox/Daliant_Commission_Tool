//
//  EmailSignUpView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/20/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Sign-up: step 1 (email entry).
/// UI-only: validates email format; on submit/Next calls onNext(email).
struct EmailSignUpView: View {
    @State private var email: String = ""
    @State private var serverErrorMessage: String? = nil
    @State private var attemptedSubmit = false
    @FocusState private var emailFocused: Bool
    @Environment(\.dismiss) private var dismiss

    /// Called when a valid email is submitted.
    var onNext: ((String) -> Void)? = nil

    private var isValid: Bool {
        // Simple but robust-enough email check for UI (server will re-validate).
        let pattern = #"^\S+@\S+\.\S+$"#
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    private var showError: Bool { attemptedSubmit && !isValid }

    var body: some View {
        VStack(spacing: 0) {

            // Title
            VStack(spacing: DS.Spacing.xs) {
                Text("Sign up with Email")
                    .font(DS.Font.title)
                // Optional subtitle could go here
            }
            .padding(.top, DS.Spacing.xl + DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.xl)

            // Input
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {

                    Text("Enter your email")
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .leading) {
                        // The field (typed text is black; cursor black)
                        TextField("", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled(true)
                            .submitLabel(.next)
                            .focused($emailFocused)
                            .foregroundStyle(.primary)    // typed text = black
                            .tint(.black)                 // cursor = black
                            .padding(.vertical, DS.Spacing.sm)
                            .padding(.horizontal, DS.Spacing.lg)
                            .frame(minHeight: DS.Card.minTap)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .fill(Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .strokeBorder(
                                        showError ? Color.red :
                                        (emailFocused ? Color.black : Color.secondary.opacity(0.35)),
                                        lineWidth: 1
                                    )
                            )
                            .onSubmit { attemptNext() }

                        // Custom placeholder (always grey, even when focused)
                        // Custom placeholder (always gray, even when focused)
                        if email.isEmpty {
                            Text(verbatim: "example@mail.com")
                                .font(DS.Font.body)               // or DS.Font.sub if you prefer smaller
                                .foregroundColor(.secondary)      // force gray (no style inheritance)
                                .padding(.horizontal, DS.Spacing.lg)
                                .allowsHitTesting(false)
                                .zIndex(1)                        // keep above the field’s text layer
                        }

                    }


                    if showError || serverErrorMessage != nil {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color.red)
                                Text(serverErrorMessage ?? "Enter a valid email address.")
                            }
                            .font(DS.Font.caption)
                            .foregroundStyle(Color.red)
                            
                            // Show "Sign in instead" link when email is already in use
                            if serverErrorMessage?.contains("already in use") == true {
                                Button("Sign in instead") {
                                    // Navigate to sign in flow
                                    navigateToSignIn()
                                }
                                .font(DS.Font.caption)
                                .foregroundStyle(.blue)
                                .padding(.leading, DS.Spacing.lg) // Align with the error text
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
            }
        }
        // Sticky Next button that floats above the keyboard
        .safeAreaInset(edge: .bottom) {
            DSUI.StickyCtaBar(
                title: "Next",
                isEnabled: isValid,
                useBackground: false,
                tint: .black
            ) {
                attemptNext()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear { emailFocused = true }
        .onChange(of: showError) { newValue in
            #if canImport(UIKit)
            if newValue {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Enter a valid email address.")
            }
            #endif
        }
    }

    private func attemptNext() {
        // Clear any prior server message
        serverErrorMessage = nil

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // If your button already guards invalid input, this is just a safety net.
        guard isValid else {
            // Keep your existing invalid message pathway (if you use attemptedSubmit/showError, keep it).
            // Example (only if you have this flag):
            // attemptedSubmit = true
            return
        }

        Task {
            do {
                let inUse = try await AuthService.isEmailInUse(trimmed)
                if inUse {
                    // Show inline red row with this copy
                    serverErrorMessage = "That email is already in use. Please sign in instead."
                    // If your UI only shows the row when `showError` is true, also toggle that flag:
                    // attemptedSubmit = true
                } else {
                    // Proceed to CreatePasswordView
                    onNext?(trimmed)
                }
            } catch {
                // Friendly fallback
                serverErrorMessage = "We couldn't check this email right now. Please try again."
                // attemptedSubmit = true
            }
        }
    }
    
    private func navigateToSignIn() {
        // Navigate back to the sign-in flow using SwiftUI's dismiss
        // This will pop back to the previous view in the navigation stack
        dismiss()
    }
}

#if DEBUG
struct EmailSignUpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EmailSignUpView { _ in print("Next with email") }
        }
    }
}
#endif
