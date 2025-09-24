//
//  EmailSignInView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/21/25.
//

import SwiftUI

struct EmailSignInView: View {
    @State private var email = ""
    @FocusState private var isFocused: Bool
    var onNext: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
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

            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            DSUI.StickyCtaBar(
                title: "Next",
                isEnabled: isValidEmail(email),
                useBackground: false,
                tint: .black
            ) {
                onNext(email.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        .padding(.horizontal, DS.Spacing.xl)
        .onAppear { isFocused = true }
        .navigationBarBackButtonHidden(false)
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
