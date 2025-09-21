//
//  NameEntryView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/20/25.
//

import SwiftUI

/// Sign-up: step 3 (collect first/last name).
/// UI-only for now. When valid, calls onCreate(first,last).
struct NameEntryView: View {
    let email: String
    let password: String
    var onCreate: ((String, String) -> Void)? = nil

    @State private var firstName: String = ""
    @State private var lastName: String  = ""
    @FocusState private var focused: Field?
    private enum Field { case first, last }

    private let maxLen = 20

    private var canCreate: Bool {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  == false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(spacing: DS.Spacing.xs) {
                Text("Name")
                    .font(DS.Font.title)
                Text("You can change this later.")
                    .font(DS.Font.sub)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, DS.Spacing.xl + DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.xl)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {

                    Text("First Name")
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)

                    nameField(
                        text: $firstName,
                        placeholder: "First Name",
                        focusedField: .first
                    )
                    .focused($focused, equals: .first)
                    .onSubmit { focused = .last }

                    Text("Last Name")
                        .font(DS.Font.sub)
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.lg)

                    nameField(
                        text: $lastName,
                        placeholder: "Last Name",
                        focusedField: .last
                    )
                    .focused($focused, equals: .last)
                    .onSubmit { attemptCreate() }

                    // Soft counter (last name as in your ref screenshot)
                    HStack {
                        Spacer()
                        Text("\(min(lastName.count, maxLen))/\(maxLen)")
                            .font(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
            }
        }
        // Sticky CTA
        .safeAreaInset(edge: .bottom) {
            DSUI.StickyCtaBar(
                title: "Create Account",
                isEnabled: canCreate,
                useBackground: false,
                tint: .black
            ) { attemptCreate() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear { focused = .first }
    }

    // MARK: - Subviews

    private func nameField(
        text: Binding<String>,
        placeholder: String,
        focusedField: Field
    ) -> some View {
        // Clamp to maxLen
        let clamped = Binding<String>(
            get: { text.wrappedValue },
            set: { newVal in text.wrappedValue = String(newVal.prefix(maxLen)) }
        )

        return ZStack(alignment: .leading) {
            TextField("", text: clamped)
                .textContentType(focusedField == .first ? .givenName : .familyName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .submitLabel(focusedField == .first ? .next : .go)
                .foregroundStyle(.primary)
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
                            (focused == focusedField ? Color.black : Color.secondary.opacity(0.35)),
                            lineWidth: 1
                        )
                )

            if clamped.wrappedValue.isEmpty {
                Text(verbatim: placeholder)
                    .font(DS.Font.body)
                    .foregroundColor(.secondary) // always gray
                    .padding(.horizontal, DS.Spacing.lg)
                    .allowsHitTesting(false)
                    .zIndex(1)
            }
        }
    }

    private func attemptCreate() {
        guard canCreate else { return }
        onCreate?(
            firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

#if DEBUG
struct NameEntryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NameEntryView(email: "example@mail.com", password: "••••••") { _, _ in
                print("Create Account tapped")
            }
        }
    }
}
#endif
