//
//  PhoneVerificationCoordinator.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/13/25.
//

import Foundation
import FirebaseAuth

final class PhoneVerificationCoordinator {
    var onCodeSent: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    func start(phoneNumber: String) {
        #if DEBUG
        print("[PhoneVerify] start send code to \(phoneNumber)")
        #endif
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { id, error in
            if let error = error {
                #if DEBUG
                print("[PhoneVerify] verifyPhoneNumber error: \(error)")
                #endif
                self.onError?(error); return
            }
            guard let verificationID = id else {
                self.onError?(NSError(domain: "PhoneVerify", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No verification ID returned"]))
                return
            }
            #if DEBUG
            print("[PhoneVerify] code sent; verificationID received")
            #endif
            self.onCodeSent?(verificationID)
        }
    }
}
