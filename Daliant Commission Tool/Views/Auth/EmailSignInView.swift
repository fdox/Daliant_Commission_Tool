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
            VStack(alignment: .leading, spacing: 8) {
                Text("Log in with Email")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Enter your email to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)


            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your email")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("example@mail.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($isFocused)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFocused ? .black : .gray.opacity(0.3), lineWidth: 1)
                    )
            }

            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button("Next") {
                    onNext(email.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .font(.headline)
                .foregroundColor(.white)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .disabled(!isValidEmail(email))
                .opacity(isValidEmail(email) ? 1 : 0.5)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }

        .padding(.horizontal, 20)
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
