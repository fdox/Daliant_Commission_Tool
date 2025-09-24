//
//  AuthFlowRoot.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/20/25.
//

import SwiftUI

/// Root router for the new Wix-style auth flow.
/// Shows the Landing, then pushes to Sign In / Sign Up choice screens.
struct AuthFlowRoot: View {
    private enum Route: Hashable {
        case signIn
        case signUp
        case signUpEmail
        case signInEmail
        case signInPassword(email: String)
        case createPassword(email: String)
        case collectName(email: String, password: String)
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            // Landing (logo + hero + two buttons)
            AuthLandingView(
                onCreateAccount: { path.append(.signUp) },
                onSignIn:       { path.append(.signIn) }
            )
            // Destinations (UI-only for now; actions are TODOs)
            // Destinations (UI-only for now; actions are TODOs)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .signIn:
                    SignInChoiceView(
                        onGoogle: { print("SignIn: Google tapped") },
                        onApple:  { print("SignIn: Apple tapped") },
                        onEmail:  { path.append(.signInEmail) }
                    )

                case .signUp:
                    SignUpChoiceView(
                        onGoogle: { print("SignUp: Google tapped") },
                        onApple:  { print("SignUp: Apple tapped") },
                        onEmail:  { path.append(.signUpEmail) }
                    )

                case .signUpEmail:
                    EmailSignUpView(
                        onNext: { email in
                            path.append(.createPassword(email: email))
                        },
                        onSwitchToSignIn: {
                            path.append(.signInEmail)
                        }
                    )
                    
                case .signInEmail:
                    EmailSignInView { email in
                        path.append(.signInPassword(email: email))
                    }

                case .signInPassword(let email):
                    PasswordSignInView(email: email)


                case .createPassword(let email):
                    CreatePasswordView(email: email) { password in
                        path.append(.collectName(email: email, password: password))
                    }

                case .collectName(let email, let password):
                    NameEntryView(email: email, password: password) { first, last in
                        // Step 7 wiring: create user, upsert profile, send verification.
                        Task {
                            do {
                                try await AuthService.createAccount(email: email, password: password)
                                try? await UserStore.upsertProfile(firstName: first, lastName: last)
 //                               if FeatureFlags.emailVerificationRequired {
 //                                   try? await AuthState.shared.sendEmailVerification()
//                                }                                // AuthGate/SignedInGate will flip automatically on state change.
                            } catch {
                                #if DEBUG
                                print("[AuthFlow] Create Account failed:", error.localizedDescription)
                                #endif
                            }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
struct AuthFlowRoot_Previews: PreviewProvider {
    static var previews: some View {
        AuthFlowRoot()
    }
}
#endif
