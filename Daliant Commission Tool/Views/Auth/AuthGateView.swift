//
//  AuthGateView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/2/25.
//

import SwiftUI

struct AuthGateView: View {
    @ObservedObject private var auth = AuthState.shared

    var body: some View {
        switch auth.status {
        case .loading:
            ProgressView("Loading…")
                .padding()
        case .signedOut:
            EmailPasswordSignInView()
        case .signedIn:
            // Your existing app entry
            ContentView()
        }
    }
}

#Preview {
    AuthGateView()
}
