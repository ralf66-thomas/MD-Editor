//
//  MarkdownView.swift
//  MD-Editor
//
//  Renders a Markdown source string as styled SwiftUI views.
//

import SwiftUI

struct MarkdownView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            MarkdownContent(markdown: markdown)
                .padding()
                .textSelection(.enabled)
        }
    }
}

struct MarkdownContent: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let blocks = MarkdownParser.parse(markdown)
            ForEach(blocks.indices, id: \.self) { index in
                MarkdownBlockView(block: blocks[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Parsed block model

struct MarkdownBlock {
    enum Kind {
        case paragraph
        case header(level: Int)
        case codeBlock(language: String?)
        case blockquote
        case listItem(ordered: Bool, ordinal: Int?, indent: Int)
        case thematicBreak
        case table(columns: [PresentationIntent.TableColumn],
                   header: [AttributedString],
                   rows: [[AttributedString]])
    }

    let kind: Kind
    let inline: AttributedString
    let plain: String
}

// MARK: - Parser

enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let attributed: AttributedString
        do {
            attributed = try AttributedString(
                markdown: source,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            return [MarkdownBlock(kind: .paragraph,
                                  inline: AttributedString(source),
                                  plain: source)]
        }

        var blocks: [MarkdownBlock] = []
        var bufferText = AttributedString()
        var bufferIntent: PresentationIntent?
        var tableBuilder: TableBuilder?

        func flushParagraphBuffer() {
            guard bufferIntent != nil || !bufferText.characters.isEmpty else { return }
            blocks.append(makeBlock(text: bufferText, intent: bufferIntent))
            bufferText = AttributedString()
            bufferIntent = nil
        }

        func flushTableBuffer() {
            if let block = tableBuilder?.build() {
                blocks.append(block)
            }
            tableBuilder = nil
        }

        for run in attributed.runs {
            let intent = run.presentationIntent
            let slice = AttributedString(attributed[run.range])

            if let intent, let tableComponent = tableComponent(in: intent) {
                flushParagraphBuffer()

                let columns: [PresentationIntent.TableColumn]
                if case .table(columns: let cols) = tableComponent.kind {
                    columns = cols
                } else {
                    columns = []
                }

                if tableBuilder?.identity != tableComponent.identity {
                    flushTableBuffer()
                    tableBuilder = TableBuilder(identity: tableComponent.identity, columns: columns)
                }

                let cellLocation = cellLocation(in: intent)
                tableBuilder?.append(text: slice,
                                     rowIdentity: cellLocation.rowIdentity,
                                     isHeader: cellLocation.isHeader,
                                     columnIndex: cellLocation.columnIndex)
            } else {
                flushTableBuffer()

                if intent != bufferIntent {
                    flushParagraphBuffer()
                    bufferIntent = intent
                }
                bufferText.append(slice)
            }
        }
        flushTableBuffer()
        flushParagraphBuffer()

        return blocks
    }

    private static func tableComponent(in intent: PresentationIntent) -> PresentationIntent.IntentType? {
        intent.components.first { component in
            if case .table = component.kind { return true }
            return false
        }
    }

    private static func cellLocation(in intent: PresentationIntent) -> (rowIdentity: Int, isHeader: Bool, columnIndex: Int) {
        var rowIdentity = 0
        var isHeader = false
        var columnIndex = 0
        for component in intent.components {
            switch component.kind {
            case .tableHeaderRow:
                isHeader = true
                rowIdentity = component.identity
            case .tableRow:
                isHeader = false
                rowIdentity = component.identity
            case .tableCell(columnIndex: let column):
                columnIndex = column
            default:
                break
            }
        }
        return (rowIdentity, isHeader, columnIndex)
    }

    private static func makeBlock(text: AttributedString, intent: PresentationIntent?) -> MarkdownBlock {
        let components = intent?.components ?? []

        var isHeader = false
        var headerLevel = 1
        var isCodeBlock = false
        var codeLanguage: String?
        var isBlockquote = false
        var isThematicBreak = false
        var inOrderedList = false
        var listOrdinal: Int?
        var listIndent = 0

        for component in components {
            switch component.kind {
            case .header(level: let level):
                isHeader = true
                headerLevel = level
            case .codeBlock(languageHint: let language):
                isCodeBlock = true
                codeLanguage = language
            case .blockQuote:
                isBlockquote = true
            case .thematicBreak:
                isThematicBreak = true
            case .orderedList:
                inOrderedList = true
                listIndent += 1
            case .unorderedList:
                listIndent += 1
            case .listItem(ordinal: let ordinal):
                listOrdinal = ordinal
            default:
                break
            }
        }

        let plain = String(text.characters)

        if isThematicBreak {
            return MarkdownBlock(kind: .thematicBreak, inline: AttributedString(), plain: "")
        }
        if isCodeBlock {
            return MarkdownBlock(kind: .codeBlock(language: codeLanguage),
                                 inline: AttributedString(plain),
                                 plain: plain)
        }
        if isHeader {
            return MarkdownBlock(kind: .header(level: headerLevel), inline: text, plain: plain)
        }
        if listIndent > 0 {
            return MarkdownBlock(
                kind: .listItem(ordered: inOrderedList,
                                ordinal: listOrdinal,
                                indent: listIndent - 1),
                inline: text,
                plain: plain
            )
        }
        if isBlockquote {
            return MarkdownBlock(kind: .blockquote, inline: text, plain: plain)
        }
        return MarkdownBlock(kind: .paragraph, inline: text, plain: plain)
    }
}

// MARK: - Table accumulation

private final class TableBuilder {
    let identity: Int
    let columns: [PresentationIntent.TableColumn]

    private var header: [AttributedString] = []
    private var rows: [[AttributedString]] = []

    private var currentRowIdentity: Int?
    private var currentRowIsHeader = false
    private var currentRowCells: [Int: AttributedString] = [:]

    init(identity: Int, columns: [PresentationIntent.TableColumn]) {
        self.identity = identity
        self.columns = columns
    }

    func append(text: AttributedString, rowIdentity: Int, isHeader: Bool, columnIndex: Int) {
        if currentRowIdentity != rowIdentity {
            commitCurrentRow()
            currentRowIdentity = rowIdentity
            currentRowIsHeader = isHeader
            currentRowCells = [:]
        }
        var existing = currentRowCells[columnIndex] ?? AttributedString()
        existing.append(text)
        currentRowCells[columnIndex] = existing
    }

    private func commitCurrentRow() {
        guard !currentRowCells.isEmpty else { return }
        let columnCount = max(columns.count, (currentRowCells.keys.max() ?? -1) + 1)
        var row: [AttributedString] = []
        for index in 0..<columnCount {
            row.append(currentRowCells[index] ?? AttributedString())
        }
        if currentRowIsHeader {
            header = row
        } else {
            rows.append(row)
        }
    }

    func build() -> MarkdownBlock? {
        commitCurrentRow()
        guard !header.isEmpty || !rows.isEmpty else { return nil }
        return MarkdownBlock(
            kind: .table(columns: columns, header: header, rows: rows),
            inline: AttributedString(),
            plain: ""
        )
    }
}

// MARK: - Block rendering

struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block.kind {
        case .thematicBreak:
            Divider()

        case .header(let level):
            Text(block.inline)
                .font(headerFont(level: level))
                .padding(.top, level <= 2 ? 6 : 2)

        case .codeBlock:
            Text(block.plain.trimmingCharacters(in: .newlines))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

        case .blockquote:
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary)
                    .frame(width: 3)
                Text(block.inline)
                    .italic()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

        case .listItem(let ordered, let ordinal, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(marker(ordered: ordered, ordinal: ordinal))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(block.inline)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(indent) * 20)

        case .paragraph:
            Text(block.inline)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .table(let columns, let header, let rows):
            MarkdownTableView(columns: columns, header: header, rows: rows)
        }
    }

    private func headerFont(level: Int) -> Font {
        switch level {
        case 1: return .system(size: 30, weight: .bold)
        case 2: return .system(size: 24, weight: .bold)
        case 3: return .system(size: 20, weight: .semibold)
        case 4: return .system(size: 18, weight: .semibold)
        case 5: return .system(size: 16, weight: .semibold)
        default: return .system(size: 14, weight: .semibold)
        }
    }

    private func marker(ordered: Bool, ordinal: Int?) -> String {
        if ordered, let ordinal { return "\(ordinal)." }
        return "•"
    }
}

private struct MarkdownTableView: View {
    let columns: [PresentationIntent.TableColumn]
    let header: [AttributedString]
    let rows: [[AttributedString]]

    private var columnCount: Int {
        let fromHeader = header.count
        let fromRows = rows.map(\.count).max() ?? 0
        return max(columns.count, fromHeader, fromRows)
    }

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            if !header.isEmpty {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        cell(content: cellContent(in: header, column: column),
                             column: column,
                             isHeader: true)
                    }
                }
                .background(Color.secondary.opacity(0.12))
            }
            ForEach(rows.indices, id: \.self) { rowIndex in
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        cell(content: cellContent(in: rows[rowIndex], column: column),
                             column: column,
                             isHeader: false)
                    }
                }
                .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func cellContent(in row: [AttributedString], column: Int) -> AttributedString {
        column < row.count ? row[column] : AttributedString()
    }

    private func cell(content: AttributedString, column: Int, isHeader: Bool) -> some View {
        Text(content)
            .font(isHeader ? .body.weight(.semibold) : .body)
            .multilineTextAlignment(textAlignment(for: column))
            .frame(maxWidth: .infinity, alignment: frameAlignment(for: column))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private func textAlignment(for column: Int) -> TextAlignment {
        switch alignment(for: column) {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        @unknown default: return .leading
        }
    }

    private func frameAlignment(for column: Int) -> Alignment {
        switch alignment(for: column) {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        @unknown default: return .leading
        }
    }

    private func alignment(for column: Int) -> PresentationIntent.TableColumn.Alignment {
        guard column < columns.count else { return .left }
        return columns[column].alignment
    }
}

#Preview {
    MarkdownView(markdown: """
    # Heading 1
    ## Heading 2

    This is a **bold** paragraph with *italic* text and a [link](https://example.com).

    - First item
    - Second item with `inline code`
    - Third item

    1. Ordered one
    2. Ordered two

    > A blockquote with some wisdom.

    | Name      | Score | Notes              |
    | :-------- | :---: | -----------------: |
    | Alice     |  92   | great work         |
    | Bob       |  78   | needs improvement  |
    | Charlie   | 100   | perfect            |

    ```
    let answer = 42
    ```

    ---
    """)
}
