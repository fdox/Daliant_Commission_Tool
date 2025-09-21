//
//  SignedInGateView.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/4/25.
//

import SwiftUI
import SwiftData

struct SignedInGateView: View {
    @State private var showVerifyGate: Bool = false
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
        .fullScreenCover(isPresented: $showVerifyGate) {
            VerifyAccountView {
                // Called when the user is verified and taps "Refresh status"
                showVerifyGate = false
                Task {
                    #if DEBUG
                    print("[SignedInGate] verification gate dismissed → resuming bootstrap")
                    #endif
                    await bootstrap()   // resume from where we paused
                }
            }
        }
        .onAppear {
            Task {
                // Keep the sheet in sync on re-appear (e.g., returning from Mail)
                try? await AuthState.shared.reloadCurrentUser()
                showVerifyGate = FeatureFlags.emailVerificationRequired && !AuthState.shared.isVerified
                #if DEBUG
                print("[SignedInGate] verifyGate show=\(showVerifyGate)")
                #endif
            }
        }
    }
    
    
    

    private func bootstrap() async {
        do {
#if DEBUG
print("[SignedInGate] ensureProfile begin")
#endif
await UserProfileService.shared.ensureProfile()

#if DEBUG
print("[SignedInGate] org bootstrap begin")
#endif
do {
    try await OrgService.shared.ensureAndSeedLocalOrg(context: context)
} catch {
    // One-shot guard: if rules denied because /users/{uid} wasn’t ready yet,
    // re-ensure profile and retry once.
    let nsErr = error as NSError
    if nsErr.domain == "FIRFirestoreErrorDomain", nsErr.code == 7 {
        #if DEBUG
        print("[SignedInGate] permissionDenied on org write → re-ensuring profile & retrying once")
        #endif
        await UserProfileService.shared.ensureProfile()
        try await OrgService.shared.ensureAndSeedLocalOrg(context: context)
    } else {
        throw error
    }
}

#if DEBUG
print("[SignedInGate] org bootstrap done; checking verification…")
#endif

do {
    try await AuthState.shared.reloadCurrentUser()
} catch {
    #if DEBUG
    print("[SignedInGate] user reload error: \(error)")
    #endif
}

            if FeatureFlags.emailVerificationRequired && !AuthState.shared.isVerified {
                #if DEBUG
                print("[SignedInGate] not verified → showing VerifyAccountView")
                #endif
                await MainActor.run { showVerifyGate = true }
                return // pause; we'll resume bootstrap after verification
            }


#if DEBUG
print("[SignedInGate] verified; pulling projects…")
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
