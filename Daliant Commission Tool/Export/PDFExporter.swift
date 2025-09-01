import Foundation
#if os(iOS)
import UIKit
import SwiftData
#endif

#if os(iOS)
struct PDFExporter {
    // Uses Design.swift tokens

    struct Column {
        let title: String
        let width: CGFloat
        let align: NSTextAlignment
        let value: (Fixture) -> String
    }

    // Static avoids touching 'self' in initializers.
    private static let columns: [Column] = [
        .init(title: "Label",        width: 130, align: .left,   value: { $0.label }),
        .init(title: "Addr",         width:  34, align: .right,  value: { String($0.shortAddress) }),
        .init(title: "Groups",       width:  82, align: .left,   value: { Self.groupsText($0.groups) }),
        .init(title: "Room",         width:  80, align: .left,   value: { $0.room ?? "" }),
        .init(title: "DT",           width:  30, align: .center, value: { $0.dtTypeRaw ?? "" }),
        .init(title: "Serial",       width:  86, align: .left,   value: { $0.serial ?? "" }),
        .init(title: "Commissioned", width:  60, align: .left,   value: { Self.dateShort($0.commissionedAt) })
    ]

    // MARK: - Public

    /// Branded, multi‑page PDF with header (logo + title + org), metadata, table, and footer.
    func render(project: Item, fixtures: [Fixture], orgName: String? = nil) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        let filename = "\(sanitize(project.title))-Commission-\(df.string(from: Date())).pdf"
        let url = tmp.appendingPathComponent(filename)

        let bounds = CGRect(origin: .zero, size: Design.pageSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(project.title) — Commission Report",
            kCGPDFContextCreator as String: "Daliant Commission Tool"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let firstRows = rowsPerPage(isFirstPage: true)
        let otherRows = rowsPerPage(isFirstPage: false)
        let totalPages = totalPagesFor(totalRows: fixtures.count, first: firstRows, other: otherRows)
        let exportedAt = Date()

        try renderer.writePDF(to: url) { ctx in
            var start = 0
            var page = 1

            repeat {
                ctx.beginPage()
                let c = ctx.cgContext

                drawHeader(in: c, orgName: orgName)
                drawFooter(in: c, page: page, totalPages: totalPages, exportedAt: exportedAt)

                var y = Design.pageMargin + Design.headerHeight + 12
                if page == 1 {
                    y = drawMetadata(in: c, fromY: y, project: project) + 12
                }

                // Table header (repeated each page)
                y = drawTableHeader(in: c, fromY: y) + 6

                let capacity = page == 1 ? firstRows : otherRows
                let end = min(start + max(capacity, 0), fixtures.count)

                var rowY = y
                if start < end {
                    for f in fixtures[start..<end] {
                        drawRow(in: c, y: rowY, fixture: f)
                        // light rule under each row
                        c.setStrokeColor(UIColor.separator.cgColor)
                        c.setLineWidth(Design.hairline)
                        c.move(to: CGPoint(x: Design.pageMargin, y: rowY + Design.rowHeight))
                        c.addLine(to: CGPoint(x: Design.pageSize.width - Design.pageMargin, y: rowY + Design.rowHeight))
                        c.strokePath()

                        rowY += (Design.rowHeight + Design.rowGap)
                    }
                }

                start = end
                page += 1
            } while start < fixtures.count
        }

        return url
    }

    // MARK: - Layout math

    private func rowsPerPage(isFirstPage: Bool) -> Int {
        let top = Design.pageMargin + Design.headerHeight + 12
        let meta: CGFloat = isFirstPage ? (5 * 20 + 12) : 0   // ~5 metadata lines @ 20pt + padding
        let table = Design.tableHeaderHeight + 6
        let bottomReserve: CGFloat = Design.pageMargin + 16
        let available = Design.pageSize.height - (top + meta + table + bottomReserve)
        return max(0, Int(floor(available / (Design.rowHeight + Design.rowGap))))
    }

    private func totalPagesFor(totalRows: Int, first: Int, other: Int) -> Int {
        guard totalRows > first, other > 0 else { return 1 }
        let remaining = totalRows - first
        let more = Int(ceil(Double(remaining) / Double(other)))
        return 1 + max(0, more)
    }

    // MARK: - Drawing

    private func drawHeader(in c: CGContext, orgName: String?) {
        let rect = CGRect(x: Design.pageMargin,
                          y: Design.pageMargin,
                          width: Design.pageSize.width - Design.pageMargin*2,
                          height: Design.headerHeight)

        // Logo (left)
        if let cg = UIImage(named: "AppLogo")?.cgImage {
            c.draw(cg, in: CGRect(x: rect.minX, y: rect.minY + 4, width: 40, height: 40))
        }

        // Title (left of center)
        drawText("Daliant Commission Tool",
                 at: CGPoint(x: rect.minX + 48, y: rect.minY + 10),
                 font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                 align: .left,
                 width: 320)

        // Org (right)
        if let org = orgName, !org.isEmpty {
            drawText(org,
                     at: CGPoint(x: rect.maxX - 200, y: rect.minY + 12),
                     font: UIFont.systemFont(ofSize: 13, weight: .regular),
                     align: .right,
                     width: 200)
        }

        // Divider
        c.setStrokeColor(UIColor.separator.cgColor)
        c.setLineWidth(Design.rule)
        c.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        c.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        c.strokePath()
    }

    private func drawFooter(in c: CGContext, page: Int, totalPages: Int, exportedAt: Date) {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        let footer = "Page \(page) of \(totalPages)   •   Exported \(df.string(from: exportedAt))"

        drawText(footer,
                 at: CGPoint(x: Design.pageMargin, y: Design.pageSize.height - Design.pageMargin - 14),
                 font: UIFont.systemFont(ofSize: 10),
                 align: .left,
                 width: Design.pageSize.width - Design.pageMargin*2)
    }

    private func drawMetadata(in c: CGContext, fromY y0: CGFloat, project: Item) -> CGFloat {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let contact = [project.contactFirstName, project.contactLastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let lines: [(String, String)] = [
            ("Project", project.title),
            ("Control System", project.controlSystemRaw ?? ""),
            ("Contact", contact),
            ("Site Address", project.siteAddress ?? ""),
            ("Created", project.createdAt.map(df.string(from:)) ?? "")
        ]

        var y = y0
        for (label, value) in lines {
            drawText("\(label):",
                     at: CGPoint(x: Design.pageMargin, y: y),
                     font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                     align: .left,
                     width: 140)
            drawText(value,
                     at: CGPoint(x: Design.pageMargin + 150, y: y),
                     font: UIFont.systemFont(ofSize: 14),
                     align: .left,
                     width: Design.pageSize.width - Design.pageMargin*2 - 150)
            y += 20
        }
        return y
    }

    private func drawTableHeader(in c: CGContext, fromY y: CGFloat) -> CGFloat {
        var xx = Design.pageMargin
        for col in Self.columns {
            drawText(col.title,
                     at: CGPoint(x: xx, y: y + 4),
                     font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                     align: .left,
                     width: col.width)
            xx += col.width + Design.colGap
        }
        c.setStrokeColor(UIColor.separator.cgColor)
        c.setLineWidth(Design.rule)
        c.move(to: CGPoint(x: Design.pageMargin, y: y + Design.tableHeaderHeight))
        c.addLine(to: CGPoint(x: Design.pageSize.width - Design.pageMargin, y: y + Design.tableHeaderHeight))
        c.strokePath()
        return y + Design.tableHeaderHeight
    }

    private func drawRow(in c: CGContext, y: CGFloat, fixture: Fixture) {
        var xx = Design.pageMargin
        for col in Self.columns {
            let text = col.value(fixture)
            let font: UIFont = (col.title == "Addr")
                ? UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                : UIFont.systemFont(ofSize: 11)

            drawText(text,
                     at: CGPoint(x: xx, y: y),
                     font: font,
                     align: col.align,
                     width: col.width,
                     height: Design.rowHeight)
            xx += col.width + Design.colGap
        }
    }

    // MARK: - Text

    private func drawText(_ text: String,
                          at origin: CGPoint,
                          font: UIFont,
                          align: NSTextAlignment,
                          width: CGFloat,
                          height: CGFloat = 1000) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style,
            .foregroundColor: UIColor.label
        ]
        (text as NSString).draw(with: CGRect(x: origin.x, y: origin.y, width: width, height: height),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: attrs,
                                context: nil)
    }

    // MARK: - Helpers

    private func sanitize(_ name: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_. ")
        let cleaned = String(name.unicodeScalars.filter { allowed.contains($0) })
        let dashed = cleaned.replacingOccurrences(of: " ", with: "-")
        let trimmed = dashed.trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return trimmed.isEmpty ? "Export" : trimmed
    }

    private static func groupsText(_ mask: UInt16) -> String {
        var parts: [String] = []
        for i in 0..<16 { if (mask & (1 << i)) != 0 { parts.append("G\(i)") } }
        return parts.joined(separator: ",")
    }

    private static func dateShort(_ d: Date?) -> String {
        guard let d else { return "" }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: d)
    }
}
#endif
