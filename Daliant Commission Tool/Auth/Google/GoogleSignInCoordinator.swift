//
//  GoogleSignInCoordinator.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/11/25.
//
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Coordinator that runs Google Sign-In and returns tokens.
/// Firebase credential wiring comes in 12c (3–4).
final class GoogleSignInCoordinator {

    struct Tokens { let idToken: String; let accessToken: String }

    // Callbacks
    var onComplete: ((Tokens) -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((Error) -> Void)?

    func start() {
        #if canImport(GoogleSignIn) && canImport(UIKit) && canImport(FirebaseCore)
        let clientID = FirebaseApp.app()?.options.clientID
            ?? (Bundle.main.object(forInfoDictionaryKey: "GID_CLIENT_ID") as? String)
        guard let clientID else {
            onError?(NSError(domain: "GoogleSignIn", code: -999,
                             userInfo: [NSLocalizedDescriptionKey: "Missing Google clientID (Firebase plist and GID_CLIENT_ID)"]))
            return
        }

        // Find a presenter for the sheet
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            onError?(NSError(domain: "GoogleSignIn", code: -998,
                             userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"]))
            return
        }

        // Configure and present Google Sign-In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error { self.onError?(error); return }
            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                self.onError?(NSError(domain: "GoogleSignIn", code: -997,
                                      userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"]))
                return
            }
            let accessToken = user.accessToken.tokenString
            self.onComplete?(Tokens(idToken: idToken, accessToken: accessToken))
        }
        #else
        onError?(NSError(domain: "GoogleSignIn", code: -996,
                         userInfo: [NSLocalizedDescriptionKey: "GoogleSignIn not available"]))
        #endif
    }
}
