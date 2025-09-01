//
//  AccountState.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/31/25.
//

// Account/AccountState.swift
// Minimal app-level account state for gating UI (no networking, no CloudKit dependency).

import Foundation

enum AccountMode: String, Codable {
    case guestLocal    // local-only
    case orgOwner      // created & owns the shared zone
    case orgMember     // accepted an invite to the shared zone
}

struct AccountState: Codable, Equatable {
    var mode: AccountMode = .guestLocal
    var orgID: UUID? = nil   // the org we're operating against (if owner/member)
    var orgName: String? = nil
}

enum AccountPrefs {
    private static let key = "account.state.v1"

    static func load() -> AccountState {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let s = try? JSONDecoder().decode(AccountState.self, from: data)
        else { return AccountState() }
        return s
    }

    static func save(_ state: AccountState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func setGuest() {
        save(AccountState(mode: .guestLocal, orgID: nil, orgName: nil))
    }

    static func setOwner(orgID: UUID, orgName: String) {
        save(AccountState(mode: .orgOwner, orgID: orgID, orgName: orgName))
    }

    static func setMember(orgID: UUID, orgName: String?) {
        save(AccountState(mode: .orgMember, orgID: orgID, orgName: orgName))
    }
}
