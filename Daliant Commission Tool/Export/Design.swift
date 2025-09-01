//
//  Design.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 8/28/25.
//

import CoreGraphics

/// Small design tokens used by the PDF exporter.
enum Design {
    static let pageSize       = CGSize(width: 612, height: 792) // US Letter @ 72 dpi
    static let pageMargin: CGFloat = 36
    static let headerHeight: CGFloat = 56
    static let tableHeaderHeight: CGFloat = 24
    static let rowHeight: CGFloat = 20
    static let rowGap: CGFloat = 2
    static let colGap: CGFloat = 6

    // Lines
    static let rule: CGFloat    = 0.5
    static let hairline: CGFloat = 0.25
}
