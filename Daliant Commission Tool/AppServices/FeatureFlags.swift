//
//  FeatureFlags.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/1/25.
//

import Foundation

enum FeatureFlags {
    static let firebaseEnabled = true
    static let cloudKitUIEnabled = false
    static let multipleOrgsEnabled = false   // ← new: we’re single-org now
    // Auth gating
    static let authOptional = false                    // when true, app is usable without signing in
    static let emailVerificationRequired = false      // when false, skip VerifyAccountView
}

