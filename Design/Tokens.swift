//
//  Tokens.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/18/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// DS = Design System tokens for consistent spacing, type, and shapes.
/// Keep this lightweight and app‑local. Prefer DS.* in new UI instead of ad‑hoc values.
enum DS {

    // MARK: Spacing (points)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Corner radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999 // for capsule/pill shapes
    }

    // MARK: Typography
    enum Font {
        /// Section/Screen titles
        static let title    = SwiftUI.Font.title2.weight(.semibold)
        /// Prominent row headings / callouts
        static let heading  = SwiftUI.Font.headline.weight(.semibold)
        /// Body copy
        static let body     = SwiftUI.Font.body
        /// Secondary labels
        static let sub      = SwiftUI.Font.subheadline
        /// Captions / helper text
        static let caption  = SwiftUI.Font.footnote
        /// Monospaced when showing codes/IDs
        static let mono     = SwiftUI.Font.system(.body, design: .monospaced)
    }

    // MARK: Icon sizing
    enum Icon {
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 28
    }

    // MARK: Opacity ramps for tints/overlays
    enum Opacity {
        static let secondary: Double = 0.66
        static let disabled:  Double = 0.35
        static let hairline:  Double = 0.12
    }

    // MARK: One‑pixel lines (device‑aware)
    enum Line {
        static var hairline: CGFloat {
            #if os(iOS)
            1.0 / UIScreen.main.scale
            #else
            0.5
            #endif
        }
    }

    // MARK: Card defaults
    enum Card {
        static let padding: CGFloat = Spacing.md
        static let corner:  CGFloat = Radius.md
        static let minTap:  CGFloat = 44
    }
}
