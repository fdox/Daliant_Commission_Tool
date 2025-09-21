//
//  CreatePasswordView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/20/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Sign-up: step 2 (create & confirm password).
/// UI-only. Validates strength + confirm; on submit/Next calls onNext(password).
struct CreatePasswordView: View {
    // Inputs from previous step (optional display if you want)
    var email: String

    // Outputs
    var onNext: ((String) -> Void)? = nil

    // State
    @State private var password: String = ""
    @State private var confirm: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirm: Bool = false
    @State private var attemptedSubmit: Bool = false
    @FocusState private var focused: Field?
    private enum Field { case password, confirm }

    // Derived rules/flags
    private var rules: CPPasswordRules {
        CPPasswordRules(
            hasUpperLower: hasUpper && hasLower,
            hasSymbol: hasSymbol,
            length: password.count
        )
    }
    private var hasUpper: Bool { password.rangeOfCharacter(from: .uppercaseLetters) != nil }
    private var hasLower: Bool { password.rangeOfCharacter(from: .lowercaseLetters) != nil }
    private var hasSymbol: Bool {
        let sym = CharacterSet.punctuationCharacters
            .union(.symbols)
        return password.rangeOfCharacter(from: sym) != nil
    }

    private var minLengthError: Bool { attemptedSubmit && !rules.minOK }
    private var mismatchError: Bool {
        attemptedSubmit && rules.minOK && !confirm.isEmpty && confirm != password
    }

    private var canContinue: Bool {
        rules.minOK && !password.isEmpty && confirm == password
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(spacing: DS.Spacing.xs) {
                Text("Create Your Password")
                    .font(DS.Font.title)
            }
            .padding(.top, DS.Spacing.xl + DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.xl)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {

                    // MARK: Password
                    Text("Password")
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)

                    passwordField(
                        text: $password,
                        isSecure: !showPassword,
                        focused: .password,
                        toggle: { showPassword.toggle() },
                        isError: minLengthError
                    )
                    .focused($focused, equals: .password)
                    .onSubmit { handlePrimarySubmit() }

                    if minLengthError {
                        errorRow("Your password must have at least 6 characters.")
                            .accessibilityHidden(false)
                    }

                    // MARK: Strength + checklist
                    HStack {
                        Text(rules.strength >= 3 ? "Strong Password" : "Password strength")
                            .font(DS.Font.heading)
                        Spacer()
                        CPPasswordStrengthMeter(strength: rules.strength)
                    }
                    CPPasswordChecklist(rules: rules)
                        .padding(.top, DS.Spacing.xs)

                    // MARK: Confirm
                    Text("Confirm password")
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.lg)

                    passwordField(
                        text: $confirm,
                        isSecure: !showConfirm,
                        focused: .confirm,
                        toggle: { showConfirm.toggle() },
                        isError: mismatchError
                    )
                    .focused($focused, equals: .confirm)
                    .onSubmit { attemptNext() }

                    if mismatchError {
                        errorRow("Passwords don't match, try again")
                            .accessibilityHidden(false)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
            }
        }
        // Sticky Next
        .safeAreaInset(edge: .bottom) {
            DSUI.StickyCtaBar(
                title: "Next",
                isEnabled: canContinue,
                useBackground: false,
                tint: .black
            ) {
                attemptNext()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear { focused = .password }
        .onChange(of: minLengthError) { newValue in
            #if canImport(UIKit)
            if newValue {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Your password must have at least six characters.")
            }
            #endif
        }
        .onChange(of: mismatchError) { newValue in
            #if canImport(UIKit)
            if newValue {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Passwords don't match, try again.")
            }
            #endif
        }
    }

    // MARK: - Subviews

    private func passwordField(
        text: Binding<String>,
        isSecure: Bool,
        focused field: Field,
        toggle: @escaping () -> Void,
        isError: Bool
    ) -> some View {
        ZStack(alignment: .trailing) {
            Group {
                if isSecure {
                    SecureField("", text: text)
                        .textContentType(.newPassword)
                } else {
                    TextField("", text: text)
                        .textContentType(.newPassword)
                }
            }
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .submitLabel(field == .password ? .next : .go)
            .foregroundStyle(.primary) // typed text = black
            .tint(.black)
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
                        isError ? Color.red :
                        (focused == field ? Color.black : Color.secondary.opacity(0.35)),
                        lineWidth: 1
                    )
            )

            // Eye toggle
            Button(action: toggle) {
                Image(systemName: isSecure ? "eye" : "eye.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .padding(.trailing, DS.Spacing.lg)
                    .foregroundStyle(isError ? Color.red : .secondary)
            }
            .accessibilityLabel(isSecure ? "Show password" : "Hide password")
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.red)
            Text(message)
        }
        .font(DS.Font.caption)
        .foregroundStyle(Color.red)
    }

    private func handlePrimarySubmit() {
        if rules.minOK {
            focused = .confirm
        } else {
            attemptedSubmit = true
        }
    }

    private func attemptNext() {
        attemptedSubmit = true
        guard canContinue else { return }
        onNext?(password)
    }
}

// MARK: - Local helpers (file-scoped)

private struct CPPasswordRules {
    var hasUpperLower: Bool
    var hasSymbol: Bool
    var length: Int

    var minOK: Bool { length >= 6 }
    var longOK: Bool { length >= 12 }

    /// 0...4 strength buckets
    var strength: Int {
        var s = 0
        if minOK { s += 1 }
        if hasUpperLower { s += 1 }
        if hasSymbol { s += 1 }
        if longOK { s += 1 }
        return s
    }
}

private struct CPPasswordStrengthMeter: View {
    var strength: Int // 0...4

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(color(for: i < strength ? strength : 0))
                    .frame(width: 28, height: 4)
            }
        }
    }

    private func color(for s: Int) -> Color {
        switch s {
        case 0: return .secondary.opacity(0.25)
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}

private struct CPPasswordChecklist: View {
    var rules: CPPasswordRules

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            row(done: rules.hasUpperLower, text: "Upper & lower case letters")
            row(done: rules.hasSymbol, text: "Symbols (#$&)")
            row(done: rules.longOK, text: "A longer password")
        }
    }

    @ViewBuilder
    private func row(done: Bool, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .imageScale(.medium)
                .foregroundStyle(done ? Color.accentColor : .secondary)
            Text(text)
                .font(DS.Font.sub)
                .foregroundStyle(.primary)
                .strikethrough(done, color: .secondary)
                .opacity(done ? 0.6 : 1.0)
        }
    }
}


#if DEBUG
struct CreatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CreatePasswordView(email: "example@mail.com") { _ in
                print("Next with password")
            }
        }
    }
}
#endif
