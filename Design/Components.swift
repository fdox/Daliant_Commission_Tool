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
    /// Slightly opinionated prominent button style using .tint.
    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DS.Font.heading)
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(minHeight: DS.Card.minTap)
                .background(
                    Capsule().fill(Color.accentColor)
                )
                .foregroundStyle(Color.white)
                .opacity(configuration.isPressed ? 0.88 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .accessibilityAddTraits(.isButton)
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
