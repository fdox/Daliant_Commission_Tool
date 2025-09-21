//
//  Components.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/18/25.
//

import SwiftUI

/// Small, reusable components built on top of DS (Design Tokens).
/// Keep these minimal and dependency‑free so Previews stay fast/safe.
enum DSUI {
    
    // MARK: - SemanticBadge
    /// Inline pill for quick status: Success / Warning / Error / Info / Neutral
    struct SemanticBadge: View {
        enum Kind {
            case success, warning, error, info, neutral
        }
        
        var kind: Kind
        var text: String
        var systemImage: String?
        
        private var color: Color {
            switch kind {
            case .success: return .green
            case .warning: return .orange
            case .error:   return .red
            case .info:    return .blue
            case .neutral: return .secondary
            }
        }
        
        var body: some View {
            HStack(spacing: DS.Spacing.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(text)
                    .font(DS.Font.caption)
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.sm)
            .foregroundStyle(kind == .neutral ? Color.primary.opacity(0.75) : color)
            .background(
                Capsule()
                    .fill((kind == .neutral ? Color.secondary.opacity(0.12) : color.opacity(0.15)))
            )
            .overlay(
                Capsule().strokeBorder((kind == .neutral ? Color.secondary.opacity(0.25) : color.opacity(0.25)),
                                       lineWidth: DS.Line.hairline)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(text))
        }
    }
    
    // MARK: - SectionHeader
    /// Consistent section header with optional trailing accessory (e.g., a badge or button).
    struct SectionHeader<Accessory: View>: View {
        let title: String
        var subtitle: String?
        @ViewBuilder var accessory: () -> Accessory
        
        init(_ title: String, subtitle: String? = nil, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
            self.title = title
            self.subtitle = subtitle
            self.accessory = accessory
        }
        
        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Font.heading)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DS.Font.sub)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: DS.Spacing.md)
                accessory()
            }
            .padding(.vertical, DS.Spacing.sm)
        }
    }
    
    // MARK: - PrimaryButtonStyle
    /// Prominent capsule button. `tint` defaults to accentColor so existing uses are unchanged.
    struct PrimaryButtonStyle: ButtonStyle {
        var tint: Color = .accentColor

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DS.Font.heading)
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: DS.Card.minTap)
                .background(Capsule().fill(tint))
                .foregroundStyle(Color.white)
                .opacity(configuration.isPressed ? 0.88 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .accessibilityAddTraits(.isButton)
        }
    }
    // MARK: - OutlineButtonStyle
    /// Secondary outline button (capsule). Tint can be customized per call site.
    struct OutlineButtonStyle: ButtonStyle {
        var tint: Color = .accentColor
        var borderOpacity: Double = 0.35
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DS.Font.heading)
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: DS.Card.minTap)
                .background(Capsule().fill(Color.clear))
                .overlay(
                    Capsule().strokeBorder(tint.opacity(borderOpacity), lineWidth: 1)
                )
                .foregroundStyle(tint)
                .opacity(configuration.isPressed ? 0.88 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .accessibilityAddTraits(.isButton)
        }
    }
    
    // MARK: - OrDivider
    /// Horizontal rule with a centered label, e.g. "Or".
    struct OrDivider: View {
        var text: String = "Or"
        var body: some View {
            HStack(spacing: DS.Spacing.md) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: DS.Line.hairline)
                    .frame(maxWidth: .infinity)
                
                Text(text)
                    .font(DS.Font.sub)
                    .foregroundStyle(.secondary)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: DS.Line.hairline)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(text))
        }
    }
    
    // MARK: - HeroHeader
    /// Logo + title + subtitle + optional hero image. Used on the auth landing screen.
    struct HeroHeader: View {
        var logo: Image? = Image("AppLogo")
        var title: String
        var subtitle: String? = nil
        /// Optional hero artwork (e.g., Pod4 snapshot). If nil, a system placeholder is shown in previews.
        var hero: Image? = nil
        
        var body: some View {
            VStack(spacing: DS.Spacing.lg) {
                if let logo {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                        .accessibilityHidden(true)
                }
                
                VStack(spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Font.title)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DS.Font.sub)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.center)
                
                Group {
                    if let hero {
                        hero
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                            .accessibilityHidden(true)
                    } else {
                        // Preview-safe placeholder when no asset exists yet.
                        Image(systemName: "lightbulb.max.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.top, DS.Spacing.sm)
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }
    
    // MARK: - TermsFooter
    /// Tiny terms/privacy footer with tappable links (markdown links -> handlers).
    struct TermsFooter: View {
        var onTerms: (() -> Void)? = nil
        var onPrivacy: (() -> Void)? = nil

        var body: some View {
            Text(.init("By continuing, you agree to Daliant’s [Terms of Use](terms) and [Privacy Policy](privacy)."))
                .font(DS.Font.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .environment(\.openURL, OpenURLAction { url in
                    switch url.absoluteString {
                    case "terms":   onTerms?();   return .handled
                    case "privacy": onPrivacy?(); return .handled
                    default:        return .systemAction
                    }
                })
        }
    }
    // MARK: - StickyCtaBar
    /// Bottom-attached primary CTA that automatically lifts above the keyboard via safeAreaInset.
    struct StickyCtaBar: View {
        var title: String
        var isEnabled: Bool = true
        /// When true, shows a frosted bar behind the button. Default off for a cleaner look.
        var useBackground: Bool = false
        /// Button fill color (defaults to black for auth flow).
        var tint: Color = .black
        var action: () -> Void

        var body: some View {
            // Use the exact same button style as elsewhere; avoid extra fixed height here
            Button(action: action) {
                Text(title)
                    .font(DS.Font.heading)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSUI.PrimaryButtonStyle(tint: tint))
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm) // subtle spacing, not extra height
            .background {
                if useBackground { Rectangle().fill(.ultraThinMaterial) }
            }
        }
    }

    // MARK: - PasswordStrength & Checklist

    struct PasswordRules {
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

    struct PasswordStrengthMeter: View {
        var strength: Int // 0...4
        private let segmentWidth: CGFloat = 28

        var body: some View {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(color(for: i < strength ? strength : 0))
                        .frame(width: segmentWidth, height: 4)
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

    struct PasswordChecklist: View {
        var rules: PasswordRules
        var body: some View {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                checklistRow(done: rules.hasUpperLower, text: "Upper & lower case letters")
                checklistRow(done: rules.hasSymbol, text: "Symbols (#$&)")
                checklistRow(done: rules.longOK, text: "A longer password")
            }
        }

        private func checklistRow(done: Bool, text: String) -> some View {
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

    // MARK: - Previews (safe, no Firebase)
    struct DSUI_Components_Previews: PreviewProvider {
        static var previews: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    
                    DSUI.SectionHeader("Account", subtitle: "Status and security") {
                        DSUI.SemanticBadge(kind: .success, text: "Verified", systemImage: "checkmark.seal.fill")
                    }
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Badges")
                            .font(DS.Font.title)
                        HStack(spacing: DS.Spacing.sm) {
                            DSUI.SemanticBadge(kind: .success, text: "Success", systemImage: "checkmark.circle.fill")
                            DSUI.SemanticBadge(kind: .warning, text: "Warning", systemImage: "exclamationmark.triangle.fill")
                            DSUI.SemanticBadge(kind: .error,   text: "Error",   systemImage: "xmark.octagon.fill")
                            DSUI.SemanticBadge(kind: .info,    text: "Info",    systemImage: "info.circle.fill")
                            DSUI.SemanticBadge(kind: .neutral, text: "Neutral")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Buttons")
                            .font(DS.Font.title)
                        Button {
                            // no-op
                        } label: {
                            Label("Primary Action", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(DSUI.PrimaryButtonStyle())
                        
                        Button("Secondary (system)"){
                            // no-op
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(DS.Spacing.xl)
            }
            .previewDisplayName("DSUI Components")
        }
    }
}
