//
//  SignedInGateView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/4/25.
//

import SwiftUI
import SwiftData

struct SignedInGateView: View {
    @Environment(\.modelContext) private var context
    @State private var isReady = false
    @State private var error: String?

    var body: some View {
        Group {
            if isReady {
                ContentView()
            } else if let error {
                VStack(spacing: 12) {
                    Text("Couldn’t load your organization").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Retry") { Task { await bootstrap() } }
                }
                .padding()
            } else {
                ProgressView("Preparing your account…").padding()
            }
        }
        .task { await bootstrap() }
    }
    

    private func bootstrap() async {
        do {
            #if DEBUG
            print("[SignedInGate] ensureAndSeedLocalOrg begin")
            #endif
            try await OrgService.shared.ensureAndSeedLocalOrg(context: context)
            
            #if DEBUG
            print("[SignedInGate] ensureAndSeedLocalOrg done; pulling projects…")
            #endif

            try await ProjectSyncService.shared.pullAllForCurrentUser(context: context)
            // 11e-2: start live listeners AFTER initial pull
            await MainActor.run { LiveSyncCenter.shared.start(context: context) }



            #if DEBUG
            print("[SignedInGate] projects pull complete")
            #endif
            isReady = true
        } catch {
            #if DEBUG
            print("[SignedInGate] error: \(error)")
            #endif
            self.error = error.localizedDescription
        }
    }
    
}


#Preview { SignedInGateView() }
