//
//  FirebaseBootstrap.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/2/25.
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        // 1) Feature flag controls all Firebase wiring for now.
        guard FeatureFlags.firebaseEnabled else {
            #if DEBUG
            print("[Firebase] Disabled via FeatureFlags.")
            #endif
            return
        }

        // 2) Avoid running during SwiftUI previews.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            #if DEBUG
            print("[Firebase] Skipped in SwiftUI previews.")
            #endif
            return
        }

        #if canImport(FirebaseCore)
        // 3) Don’t double-configure.
        if FirebaseApp.app() != nil { return }

        // 4) Configure only if the config file is present.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            #if DEBUG
            print("[Firebase] Configured.")
            #endif
        } else {
            // Safe no-op in 11.a; we’ll add the plist in 11.b/11.c.
            #if DEBUG
            print("[Firebase] GoogleService-Info.plist not found; skipping configure.")
            #endif
#if DEBUG
if let app = FirebaseApp.app() {
    print("[Firebase] projectID=\(app.options.projectID ?? "nil"), appID=\(app.options.googleAppID)")
}
#endif
        }
        #else
        #if DEBUG
        print("[Firebase] FirebaseCore not available in this build.")
        #endif
        #endif
    }
}
