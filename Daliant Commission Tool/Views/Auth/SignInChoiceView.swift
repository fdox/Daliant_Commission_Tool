//
//  SignInChoiceView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/20/25.
//

import SwiftUI
import AuthenticationServices

/// Sign-in choice screen (Wix-style).
/// UI-only: actions are provided as callbacks and will be wired in Step 5.
struct SignInChoiceView: View {
    // Callbacks
    var onGoogle: (() -> Void)? = nil
    var onApple:  (() -> Void)? = nil
    var onEmail:  (() -> Void)? = nil
    var onTerms:  (() -> Void)? = nil
    var onPrivacy:(() -> Void)? = nil
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                
                // Title, dropped a bit lower from the top
                VStack(spacing: DS.Spacing.xs) {
                    Text("Welcome Back!")
                        .font(DS.Font.title)
                    Text("Log in to your Daliant account to continue")
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.xl + DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.xl)
                
                // Push the provider stack toward the vertical center
                Spacer(minLength: 0)
                
                // Social providers
                VStack(spacing: DS.Spacing.md) {
                    GoogleSignInButton(title: "Continue with Google") { onGoogle?() }
                    AppleContinueButton { onApple?() } // custom, logo left + centered title
                }
                .padding(.horizontal, DS.Spacing.xl)
                
                // Or divider
                DSUI.OrDivider()
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                
                // Email (outlined in black), icon left + centered title
                OutlinedLeadingIconButton(
                    title: "Log in with Email",
                    systemImage: "envelope",
                    tint: .primary
                ) { onEmail?() }
                    .padding(.horizontal, DS.Spacing.xl)
                
                // Bottom spacer to lift the whole section closer to center
                Spacer(minLength: 0)
                    .frame(height: max(DS.Spacing.lg, proxy.size.height * 0.12))
            }
            .safeAreaInset(edge: .bottom) {
                DSUI.TermsFooter(onTerms: onTerms, onPrivacy: onPrivacy)
                    .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
        }
    }
    
    private struct GoogleSignInButton: View {
        var title: String = "Continue with Google"
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    // Centered title
                    Text(title)
                        .font(DS.Font.heading)
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: DS.Card.minTap)
                .background(Capsule().fill(Color.secondary.opacity(0.08)))
                .overlay(
                    Capsule().strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                // Left-aligned colored "G" glyph overlay
                .overlay(alignment: .leading) {
                    GoogleGlyph()
                        .frame(width: 24, height: 24)
                        .padding(.leading, DS.Spacing.lg)
                }
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isButton)
        }
    }
    
    /// Simple colored "G" inside a white circle (preview-safe fallback until a proper asset is added).
    private struct GoogleGlyph: View {
        var body: some View {
            ZStack {
                Circle().fill(Color.white)
                Text("G")
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 66/255, green: 133/255, blue: 244/255), // blue
                                Color(red: 234/255, green: 67/255,  blue: 53/255), // red
                                Color(red: 251/255, green: 188/255, blue: 5/255),  // yellow
                                Color(red: 52/255,  green: 168/255, blue: 83/255)  // green
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            .accessibilityHidden(true)
        }
    }
    
    private struct AppleContinueButton: View {
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    Text("Continue with Apple")
                        .font(DS.Font.heading)
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: DS.Card.minTap)
                .background(Capsule().fill(Color.black))
                .foregroundStyle(Color.white)
                .overlay(alignment: .leading) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.leading, DS.Spacing.lg)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Continue with Apple")
        }
    }
    
    /// Generic outlined button with a leading SF Symbol and a centered title.
    private struct OutlinedLeadingIconButton: View {
        var title: String
        var systemImage: String
        var tint: Color = .primary
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                ZStack {
                    Text(title)
                        .font(DS.Font.heading)
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: DS.Card.minTap)
                .background(Capsule().fill(Color.clear))
                .overlay(
                    Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1)
                )
                .foregroundStyle(tint)
                .overlay(alignment: .leading) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.leading, DS.Spacing.lg)
                        .foregroundStyle(tint)
                }
            }
            .buttonStyle(.plain)
            .clipShape(Capsule())
            .accessibilityLabel(Text(title))
        }
    }
    
} // end of SignInChoiceView

#if DEBUG
struct SignInChoiceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                SignInChoiceView(
                    onGoogle: { print("Google tapped") },
                    onApple:  { print("Apple tapped") },
                    onEmail:  { print("Email tapped") }
                )
            }
            .previewDisplayName("Default")

            NavigationStack {
                SignInChoiceView()
            }
            .environment(\.sizeCategory, .accessibilityMedium)
            .previewDisplayName("Accessible")
        }
    }
}
#endif

