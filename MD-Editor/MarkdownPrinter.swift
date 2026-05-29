//
//  MarkdownPrinter.swift
//  MD-Editor
//
//  Prints the rendered Markdown view via NSPrintOperation. The standard
//  macOS print panel exposes "Save as PDF" through its PDF dropdown.
//

import SwiftUI
import AppKit
import PDFKit

// MARK: - Focused value plumbing

private struct MarkdownDocumentTextKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    var markdownDocumentText: String? {
        get { self[MarkdownDocumentTextKey.self] }
        set { self[MarkdownDocumentTextKey.self] = newValue }
    }
}

/// Singleton fallback so the File-menu Print command can always reach the
/// currently-focused document's text, even when FocusedValue propagation
/// hasn't run yet (e.g. immediately after launching).
final class CurrentMarkdownDocument {
    static let shared = CurrentMarkdownDocument()
    var text: String = ""
    private init() {}
}

// MARK: - Print operation

enum MarkdownPrinter {
    static func print(markdown: String, jobTitle: String = "MD-Editor") {
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 54
        printInfo.bottomMargin = 54
        printInfo.leftMargin = 54
        printInfo.rightMargin = 54

        guard
            let pdfData = renderPDF(markdown: markdown, printInfo: printInfo),
            let pdfDocument = PDFDocument(data: pdfData)
        else { return }

        guard let operation = pdfDocument.printOperation(
            for: printInfo,
            scalingMode: .pageScaleNone,
            autoRotate: false
        ) else { return }
        operation.jobTitle = jobTitle
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    /// Renders `MarkdownContent` to a paginated PDF. SwiftUI views can't be
    /// drawn directly by `NSPrintOperation`'s draw cycle, so we capture the
    /// rendering into a CGContext-backed PDF first.
    private static func renderPDF(markdown: String, printInfo: NSPrintInfo) -> Data? {
        let pageSize = printInfo.paperSize
        let leftMargin = printInfo.leftMargin
        let topMargin = printInfo.topMargin
        let rightMargin = printInfo.rightMargin
        let bottomMargin = printInfo.bottomMargin

        let contentWidth = pageSize.width - leftMargin - rightMargin
        let contentHeight = pageSize.height - topMargin - bottomMargin

        let view = MarkdownContent(markdown: markdown)
            .frame(width: contentWidth, alignment: .leading)
            .padding(.vertical, 8)
            .background(Color.white)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        renderer.render { size, drawCallback in
            let totalHeight = size.height
            let pageCount = max(1, Int(ceil(totalHeight / contentHeight)))

            for pageIndex in 0..<pageCount {
                context.beginPDFPage(nil)
                context.saveGState()

                // Clip to the page's content area in raw PDF coords (Y-up).
                context.clip(to: CGRect(
                    x: leftMargin,
                    y: bottomMargin,
                    width: contentWidth,
                    height: contentHeight
                ))

                // ImageRenderer's draw callback applies its own Y-flip to
                // convert the SwiftUI view's top-left origin to PDF's Y-up
                // origin (it composes translate(0, size.height) · scale(1, -1)).
                // We only need to translate so that the slice for this page
                // lands inside the content area: a view point (x, y) ends up
                // at PDF (tx + x, ty + size.height - y), so set ty such that
                // view-y = pageIndex*contentHeight maps to pageSize.height - topMargin.
                let ty = pageSize.height
                    - topMargin
                    - totalHeight
                    + CGFloat(pageIndex) * contentHeight
                context.translateBy(x: leftMargin, y: ty)

                drawCallback(context)

                context.restoreGState()
                context.endPDFPage()
            }
        }

        context.closePDF()
        return pdfData as Data
    }
}

// MARK: - Menu command

struct PrintCommands: Commands {
    @FocusedValue(\.markdownDocumentText) private var focusedText

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                let text = focusedText ?? CurrentMarkdownDocument.shared.text
                MarkdownPrinter.print(markdown: text)
            }
            .keyboardShortcut("p", modifiers: .command)
        }
    }
}
