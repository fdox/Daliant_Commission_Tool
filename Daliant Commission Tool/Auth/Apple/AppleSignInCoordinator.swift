//
//  AppleSignInCoordinator.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/9/25.
//

import Foundation
import AuthenticationServices

/// Coordinator that runs the native Sign in with Apple flow and returns the Apple credential + raw nonce used.
/// Firebase wiring comes in steps 3–4.
final class AppleSignInCoordinator: NSObject {

    // MARK: - Callbacks
    /// Called on success with Apple's credential and the RAW nonce we generated (you'll hash it before the request).
    var onComplete: ((ASAuthorizationAppleIDCredential, String) -> Void)?
    /// Called when the user cancels the dialog.
    var onCancel: (() -> Void)?
    /// Called on any non-cancel error.
    var onError: ((Error) -> Void)?

    // MARK: - Init
    private weak var anchor: ASPresentationAnchor?
    private var currentRawNonce: String?

    init(presentationAnchor: ASPresentationAnchor?) {
        self.anchor = presentationAnchor
    }

    // MARK: - Public API
    /// Starts the Apple Sign-In flow. Generates a fresh nonce per attempt.
    func start() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let rawNonce = AppleNonce.random()
        currentRawNonce = rawNonce
        request.nonce = AppleNonce.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let rawNonce = currentRawNonce
        else {
            onError?(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing credential/nonce"]))
            return
        }
        onComplete?(credential, rawNonce)
        currentRawNonce = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let err = error as? ASAuthorizationError, err.code == .canceled {
            onCancel?()
        } else {
            onError?(error)
        }
        currentRawNonce = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Prefer the provided anchor if available; otherwise fall back to key window.
        if let anchor = anchor { return anchor }
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
