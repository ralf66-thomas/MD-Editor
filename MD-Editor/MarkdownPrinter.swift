//
//  MarkdownPrinter.swift
//  MD-Editor
//
//  Prints the rendered Markdown view via NSPrintOperation. The standard
//  macOS print panel exposes "Save as PDF" through its PDF dropdown.
//

import SwiftUI
import AppKit

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
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic

        let pageSize = printInfo.paperSize
        let contentWidth = pageSize.width
            - printInfo.leftMargin
            - printInfo.rightMargin

        let rootView = MarkdownContent(markdown: markdown)
            .frame(width: contentWidth, alignment: .leading)
            .padding(.vertical, 8)
            .background(Color.white)
            .environment(\.colorScheme, .light)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 10)
        hostingView.layoutSubtreeIfNeeded()
        let fittingHeight = max(hostingView.fittingSize.height, 100)
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: fittingHeight)
        hostingView.layoutSubtreeIfNeeded()

        let operation = NSPrintOperation(view: hostingView, printInfo: printInfo)
        operation.jobTitle = jobTitle
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
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
