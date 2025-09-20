//
//  States.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/18/25.
//

import SwiftUI

/// Reusable empty / loading / error states that use DS tokens.
/// Keep these minimal so Previews stay fast and safe.
enum DSState {

    // MARK: Empty
    struct Empty: View {
        var title: String
        var systemImage: String
        var message: String? = nil
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: DS.Spacing.md) {
                ContentUnavailableView(
                    title,
                    systemImage: systemImage,
                    description: message.map { Text($0) }
                )
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("dsstate_empty_action")
                }
            }
            .padding(DS.Spacing.lg)
        }
    }

    // MARK: Loading
    struct Loading: View {
        var title: String = "Loading"
        var message: String? = nil

        var body: some View {
            VStack(spacing: DS.Spacing.md) {
                ProgressView().progressViewStyle(.circular)
                Text(title).font(DS.Font.heading)
                if let message {
                    Text(message)
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DS.Spacing.lg)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Error
    struct ErrorView: View {
        var title: String = "Something went wrong"
        var message: String? = nil
        var retryTitle: String? = "Try Again"
        var onRetry: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: DS.Spacing.md) {
                ContentUnavailableView(
                    title,
                    systemImage: "exclamationmark.triangle",
                    description: message.map { Text($0) }
                )
                if let onRetry, let retryTitle {
                    Button(retryTitle) { onRetry() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("dsstate_error_retry")
                }
            }
            .padding(DS.Spacing.lg)
        }
    }
}

// MARK: - Safe previews
#Preview("States") {
    ScrollView {
        VStack(spacing: DS.Spacing.xl) {
            DSState.Empty(title: "No Results", systemImage: "magnifyingglass", message: "Try a different search.")
            DSState.Loading(title: "Syncing", message: "Pulling latest data…")
            DSState.ErrorView(title: "Offline", message: "Check your connection and try again.")
        }
        .padding()
    }
}
