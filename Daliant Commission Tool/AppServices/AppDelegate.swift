//
//  AppDelegate.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/2/25.
//

import UIKit
import FirebaseAuth
import GoogleSignIn


final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()
        return true
    }

    // Google Sign-In + Firebase Auth (Phone reCAPTCHA) URL callbacks
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
}

