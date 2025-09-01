//
//  ShareSheet.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import SwiftUI
#if os(iOS)
import UIKit

/// Minimal wrapper around UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) { }
}
#endif
