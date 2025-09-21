//
//  AuthLandingView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/19/25.
//

import SwiftUI

/// Wix-style landing that lets the user choose Sign Up or Sign In before seeing the providers.
/// UI-only in this step. Actions are callbacks we’ll wire later in routing (Step 5).
struct AuthLandingView: View {
    // Callbacks (optional for previews)
    var onCreateAccount: (() -> Void)? = nil
    var onSignIn: (() -> Void)? = nil
    var onTerms: (() -> Void)? = nil
    var onPrivacy: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                
                // Scrollable hero (logo already above title in HeroHeader)
                ScrollView(showsIndicators: false) {
                    DSUI.HeroHeader(
                        title: "Configure. Verify. Export.",
                        subtitle: "Everything you need to commission Pod4 on site.",
                        hero: nil
                    )
                    .padding(.top, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // CTAs, raised ~15% from absolute bottom
                VStack(spacing: DS.Spacing.md) {
                    Button {
                        onCreateAccount?()
                    } label: {
                        Text("Create an Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSUI.PrimaryButtonStyle(tint: .black))
                    .accessibilityLabel("Create an Account")
                    
                    Button {
                        onSignIn?()
                    } label: {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSUI.OutlineButtonStyle(tint: .primary))
                    .accessibilityLabel("Sign In")
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, max(DS.Spacing.lg, proxy.size.height * 0.15)) // ← lift ~15%
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemBackground))
        }
    }
}
    
#if DEBUG
    struct AuthLandingView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                NavigationStack {
                    AuthLandingView()
                }
                .previewDisplayName("Default")
                
                NavigationStack {
                    AuthLandingView(
                        onCreateAccount: { print("Create Account tapped") },
                        onSignIn: { print("Sign In tapped") }
                    )
                }
                .environment(\.sizeCategory, .accessibilityMedium)
                .previewDisplayName("Accessible")
            }
        }
    }
#endif
