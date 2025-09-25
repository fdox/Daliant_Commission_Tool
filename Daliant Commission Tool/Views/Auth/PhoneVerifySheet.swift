//
//  PhoneVerifySheet.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import SwiftUI
import FirebaseAuth

struct PhoneVerifySheet: View {
    var onLinked: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var phone: String = ""
    @State private var verificationID: String?
    @State private var code: String = ""

    @State private var isSending = false
    @State private var isLinking = false
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if verificationID == nil {
                    Text("Verify your phone")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("+1 555 123 4567", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    Button {
                        sendCode()
                    } label: {
                        HStack { Image(systemName: "message")
                            Text("Send code") }
                    }
                    .buttonStyle(DSUI.PrimaryButtonStyle(tint: .blue))
                    .disabled(isSending || phone.trimmingCharacters(in: .whitespaces).isEmpty)

                    if isSending { ProgressView() }
                } else {
                    Text("Enter the code we sent to")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(phone)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("6-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .submitLabel(.done)


                    Button {
                        verifyAndLink()
                    } label: {
                        HStack { Image(systemName: "checkmark.seal")
                            Text("Verify & Link") }
                    }
                    .buttonStyle(DSUI.PrimaryButtonStyle(tint: .blue))
                    .disabled(isLinking || code.trimmingCharacters(in: .whitespaces).isEmpty)

                    if isLinking { ProgressView() }
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Phone Verification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func sendCode() {
        guard !isSending else { return }
        errorText = nil

        // Normalize to E.164
        guard let e164 = normalizedE164(phone) else {
            errorText = "Enter your number in international format, e.g. +1 480 555 1234."
            return
        }

        isSending = true
        let c = PhoneVerificationCoordinator()
        c.onError = { err in
            Task { @MainActor in
                self.errorText = userMessage(for: err)
                self.isSending = false
            }
        }
        c.onCodeSent = { id in
            Task { @MainActor in
                self.verificationID = id
                self.isSending = false
            }
        }
        c.start(phoneNumber: e164)
    }


    private func verifyAndLink() {
        guard let verificationID else { return }
        errorText = nil
        isLinking = true

        Task { @MainActor in
            do {
                _ = try await AuthState.shared.linkWithPhone(verificationID: verificationID, code: code)
                try? await AuthState.shared.reloadCurrentUser()
                await UserProfileService.shared.setPhone(Auth.auth().currentUser?.phoneNumber)
                try await UserProfileService.shared.refreshProviderIDsFromAuth()

                #if DEBUG
                print("[PhoneVerify] linked; providers refreshed")
                #endif
                isLinking = false
                onLinked?(Auth.auth().currentUser?.phoneNumber ?? "")
                dismiss()
            } catch {
                isLinking = false
                self.errorText = (error as NSError).localizedDescription
                #if DEBUG
                print("[PhoneVerify] link error: \(error)")
                #endif
            }
        }
    }
    private func normalizedE164(_ input: String) -> String? {
        // Keep + and digits only
        let raw = input.filter { "+0123456789".contains($0) }
        if raw.isEmpty { return nil }

        if raw.first == "+" {
            // Already has country code
            return raw
        } else {
            // If exactly 10 digits, assume US (+1)
            let digitsOnly = raw.filter(\.isNumber)
            if digitsOnly.count == 10 {
                return "+1" + digitsOnly
            } else {
                return nil
            }
        }
    }

    private func userMessage(for error: Error) -> String {
        let ns = error as NSError
        guard let code = AuthErrorCode(rawValue: ns.code) else {
            return ns.localizedDescription
        }
        switch code {
        case .invalidPhoneNumber, .missingPhoneNumber:
            return "That phone number wasn’t recognized. Use full international format, e.g. +1 480 555 1234."
        case .quotaExceeded, .tooManyRequests:
            return "We’ve sent too many codes recently. Please try again later or use a test number during development."
        case .captchaCheckFailed, .webContextAlreadyPresented:
            return "Couldn’t complete verification. Close any verification screens and try again."
        case .networkError:
            return "Network error. Check your connection and try again."
        default:
            return ns.localizedDescription
        }
    }

}

#Preview("PhoneVerifySheet") {
    PhoneVerifySheet()
}
