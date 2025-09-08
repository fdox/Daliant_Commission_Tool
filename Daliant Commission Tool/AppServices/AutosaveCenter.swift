//
//  AutosaveCenter.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/5/25.
//

//
//  AutosaveCenter.swift
//  11f: Debounced autosave + unified update stamping
//

import Foundation
import SwiftData
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class AutosaveCenter {
    static let shared = AutosaveCenter()
    private init() {}

    private let saveDebouncer = Debouncer(interval: 0.35)

    // MARK: Stamping helpers

    func touch(_ project: Item, context: ModelContext) {
        project.updatedAt = Date()
        #if canImport(FirebaseAuth)
        project.updatedBy = Auth.auth().currentUser?.uid
        #endif
        scheduleSave(context)
    }

    func touch(_ fixture: Fixture, context: ModelContext) {
        fixture.updatedAt = Date()
        #if canImport(FirebaseAuth)
        fixture.updatedBy = Auth.auth().currentUser?.uid
        #endif
        scheduleSave(context)
    }

    // MARK: Internal

    private func scheduleSave(_ context: ModelContext) {
        saveDebouncer.run { [weak context] in
            guard let context else { return }
            do { try context.save() }
            catch { print("[Autosave] save error: \(error)") }
        }
    }
}

/// Minimal main-actor debouncer
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
