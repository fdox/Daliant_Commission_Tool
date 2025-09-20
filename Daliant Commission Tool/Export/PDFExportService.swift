//
//  PDFExportService.swift
//  Daliant Commission Tool
//
//  Created by Fred Dox on 9/19/25.
//

import Foundation
import UIKit   // UIGraphicsPDFRenderer

/// Minimal PDF export with a paginated fixtures table.
/// Called from Views/ExportView.swift.
struct PDFExportService {
    static let shared = PDFExportService()

    /// Generate a PDF and return its temp file URL.
    func generate(project: Item, fixtures: [Fixture], orgName: String? = nil) throws -> URL {
        // US Letter 8.5"x11" @ 72 dpi
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Project – \(project.title)",
            kCGPDFContextAuthor as String: orgName ?? "Daliant Commission Tool"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            var y = drawHeader(in: pageRect, project: project, orgName: orgName)
            y = drawMeta(in: pageRect, startY: y + 10, project: project, fixturesCount: fixtures.count)

            // Draw fixtures; this function handles page breaks and per‑page footer.
            drawFixturesTable(ctx: ctx, in: pageRect, startY: y + 18, fixtures: fixtures, project: project, orgName: orgName)
        }

        let filename = safeFileName("Project-\(project.title)-\(Int(Date().timeIntervalSince1970)).pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Drawing

    /// Header returns the next baseline Y after it draws.
    @discardableResult
    private func drawHeader(in rect: CGRect, project: Item, orgName: String?) -> CGFloat {
        let left: CGFloat = 36
        let right: CGFloat = rect.width - 36
        var y: CGFloat = 36

        // Optional logo
        if let logo = UIImage(named: "AppLogo") {
            let h: CGFloat = 26
            let w = h * (logo.size.width / max(1, logo.size.height))
            logo.draw(in: CGRect(x: left, y: y, width: w, height: h))
            y += h + 8
        }

        // Title
        let title = "Project Report"
        title.draw(at: CGPoint(x: left, y: y),
                   withAttributes: [.font: UIFont.systemFont(ofSize: 22, weight: .semibold)])
        y += 28

        // Project line
        let smallAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        ("Project: " + project.title).draw(at: CGPoint(x: left, y: y), withAttributes: smallAttrs)
        y += 18

        if let org = orgName, !org.isEmpty {
            ("Organization: " + org).draw(at: CGPoint(x: left, y: y), withAttributes: smallAttrs)
            y += 18
        }

        // Divider
        let path = UIBezierPath()
        path.move(to: CGPoint(x: left, y: y + 6))
        path.addLine(to: CGPoint(x: right, y: y + 6))
        path.lineWidth = 0.5
        UIColor.separator.setStroke()
        path.stroke()
        y += 12
        return y
    }

    /// Metadata block returns next Y.
    @discardableResult
    private func drawMeta(in rect: CGRect, startY: CGFloat, project: Item, fixturesCount: Int) -> CGFloat {
        let left: CGFloat = 36
        var y = startY

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        func row(_ label: String, _ value: String) {
            let labelWidth: CGFloat = 118
            (label + ":").draw(at: CGPoint(x: left, y: y), withAttributes: labelAttrs)
            value.draw(at: CGPoint(x: left + labelWidth, y: y), withAttributes: valueAttrs)
            y += 20
        }

        row("Date", Self.dateFormatter.string(from: Date()))
        row("Fixtures", "\(fixturesCount)")

        if let cs = project.controlSystemRaw, !cs.isEmpty {
            row("Control System", prettyControlSystem(cs))
        }
        if let site = project.siteAddress, !site.isEmpty {
            row("Site", site)
        }

        return y
    }

    /// Draw a paginated fixtures table. Handles page breaks and ensures footers are drawn per page.
    private func drawFixturesTable(ctx: UIGraphicsPDFRendererContext,
                                   in rect: CGRect,
                                   startY: CGFloat,
                                   fixtures: [Fixture],
                                   project: Item,
                                   orgName: String?) {
        let left: CGFloat = 36
        let right: CGFloat = rect.width - 36
        let bottomMargin: CGFloat = 48
        let rowH: CGFloat = 18
        let gap: CGFloat = 8

        // Column layout (fits in 540pt content width)
        let colLabelW: CGFloat = 260
        let colRoomW:  CGFloat = 140
        let colAddrW:  CGFloat = 50
        let colDTW:    CGFloat = 50

        let xLabel = left
        let xRoom  = xLabel + colLabelW + gap
        let xAddr  = xRoom  + colRoomW  + gap
        let xDT    = right - colDTW

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let cellSubtle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let truncating: NSParagraphStyle = {
            let p = NSMutableParagraphStyle()
            p.lineBreakMode = .byTruncatingTail
            return p
        }()

        func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, attrs: [NSAttributedString.Key: Any]) {
            var a = attrs
            a[.paragraphStyle] = truncating
            NSString(string: text).draw(in: CGRect(x: x, y: y, width: width, height: rowH), withAttributes: a)
        }

        func drawTableHeader(at y: CGFloat) -> CGFloat {
            drawText("Label", x: xLabel, y: y, width: colLabelW, attrs: headerAttrs)
            drawText("Room",  x: xRoom,  y: y, width: colRoomW,  attrs: headerAttrs)
            drawText("Addr",  x: xAddr,  y: y, width: colAddrW,  attrs: headerAttrs)
            drawText("DT",    x: xDT,    y: y, width: colDTW,    attrs: headerAttrs)
            // underline
            let path = UIBezierPath()
            path.move(to: CGPoint(x: left, y: y + rowH + 3))
            path.addLine(to: CGPoint(x: right, y: y + rowH + 3))
            path.lineWidth = 0.5
            UIColor.separator.setStroke()
            path.stroke()
            return y + rowH + 6
        }

        func drawFooterOnCurrentPage() {
            let text = "Generated by Daliant Commission Tool"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let size = text.size(withAttributes: attrs)
            let x = (rect.width - size.width) / 2
            let y = rect.height - size.height - 24
            text.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }

        var y = startY
        // Ensure at least some space before placing header; break if too close to bottom.
        if y > rect.height - bottomMargin - (rowH * 2) {
            drawFooterOnCurrentPage()
            ctx.beginPage()
            y = 36
        }
        y = drawTableHeader(at: y)

        for fx in fixtures {
            // Page break?
            if y > rect.height - bottomMargin - rowH {
                drawFooterOnCurrentPage()
                ctx.beginPage()
                // (Optional) small header/title could go here; for now just the table header again.
                y = drawTableHeader(at: 36)
            }

            // Row content
            drawText(fx.label, x: xLabel, y: y, width: colLabelW, attrs: cellAttrs)
            let room = (fx.room?.isEmpty == false) ? fx.room! : "—"
            drawText(room, x: xRoom, y: y, width: colRoomW, attrs: cellSubtle)
            drawText("\(fx.shortAddress)", x: xAddr, y: y, width: colAddrW, attrs: cellAttrs)
            drawText(fx.dtTypeRaw ?? "—", x: xDT, y: y, width: colDTW, attrs: cellSubtle)

            // Row separator
            let path = UIBezierPath()
            path.move(to: CGPoint(x: left, y: y + rowH + 2))
            path.addLine(to: CGPoint(x: right, y: y + rowH + 2))
            path.lineWidth = 0.25
            UIColor.separator.setStroke()
            path.stroke()

            y += rowH + 4
        }

        // Footer on the last page
        drawFooterOnCurrentPage()
    }

    // MARK: - Helpers

    private func safeFileName(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return raw.components(separatedBy: invalid).joined()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// Local helper duplicated here so this file is standalone.
// Matches the pretty capitalization used elsewhere.
private func prettyControlSystem(_ raw: String) -> String {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch s {
    case "control4", ".control4": return "Control4"
    case "crestron", ".crestron": return "Crestron"
    case "lutron", ".lutron":     return "Lutron"
    default: return raw.isEmpty ? "—" : raw
    }
}
