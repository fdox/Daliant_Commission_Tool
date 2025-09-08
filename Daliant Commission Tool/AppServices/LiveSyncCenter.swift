//
//  LiveSyncCenter.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/5/25.
//

//
//  LiveSyncCenter.swift
//  Daliant Commission Tool
//
//  11e-2: Centralizes Firestore snapshot listeners for projects & fixtures.
//  - Starts/stops listeners for the signed-in user
//  - On remote changes, triggers a coalesced pull for Projects + Fixtures
//  - Fully gated: safe in Previews and when Firebase is disabled
//

import Foundation
import SwiftData

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class LiveSyncCenter {
    static let shared = LiveSyncCenter()
    private init() {}

    private var startedForUid: String?
    #if canImport(FirebaseFirestore)
    private var projectsListener: ListenerRegistration?
    private var fixturesListener: ListenerRegistration?
    #endif

    private var context: ModelContext?
    private let pullDebouncer = Debouncer(interval: 0.40)

    func start(context: ModelContext) {
        guard FeatureFlags.firebaseEnabled, !Self.isPreview else { return }
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("[LiveSync] start skipped — no signed-in user")
            #endif
            return
        }
        if startedForUid == uid, projectsListener != nil, fixturesListener != nil {
            #if DEBUG
            print("[LiveSync] already running for uid=\(uid)")
            #endif
            return
        }

        stop() // clear previous
        self.context = context
        self.startedForUid = uid

        let db = Firestore.firestore()
        projectsListener = db.collection("projects")
            .whereField("ownerUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] _, error in
                guard let self else { return }
                if let error { print("[LiveSync] projects listener error: \(error)") }
                self.schedulePull()
            }

        fixturesListener = db.collection("fixtures")
            .whereField("ownerUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] _, error in
                guard let self else { return }
                if let error { print("[LiveSync] fixtures listener error: \(error)") }
                self.schedulePull()
            }

        #if DEBUG
        print("[LiveSync] started for uid=\(uid)")
        #endif
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        projectsListener?.remove(); projectsListener = nil
        fixturesListener?.remove(); fixturesListener = nil
        if let uid = startedForUid { print("[LiveSync] stopped (uid=\(uid))") }
        #endif
        startedForUid = nil
        context = nil
    }

    private func schedulePull() {
        pullDebouncer.run { [weak self] in
            guard let self, let ctx = self.context else { return }
            Task { @MainActor in
                do {
                    try await ProjectSyncService.shared.pullAllForCurrentUser(context: ctx)
                    try await FixtureSyncService.shared.pullAllForCurrentUser(context: ctx)
                    #if DEBUG
                    print("[LiveSync] pull applied")
                    #endif
                } catch {
                    #if DEBUG
                    print("[LiveSync] pull error: \(error)")
                    #endif
                }
            }
        }
    }

    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

/// Tiny main-actor debouncer to coalesce bursts of remote changes.
@MainActor
fileprivate final class Debouncer {
    private let interval: TimeInterval
    private var workItem: DispatchWorkItem?

    init(interval: TimeInterval) { self.interval = interval }

    func run(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: block)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
    }
}
