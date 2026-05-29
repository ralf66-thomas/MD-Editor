//
//  ContentView.swift
//  MD-Editor
//
//  Created by Ralf Thomas on 29.05.26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: MD_EditorDocument
    @State private var mode: ViewMode = .preview

    enum ViewMode: String, CaseIterable, Identifiable {
        case edit = "Edit"
        case preview = "Preview"
        case split = "Split"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            switch mode {
            case .edit:
                TextEditor(text: $document.text)
                    .font(.system(.body, design: .monospaced))
            case .preview:
                MarkdownView(markdown: document.text)
            case .split:
                HStack(spacing: 0) {
                    TextEditor(text: $document.text)
                        .font(.system(.body, design: .monospaced))
                    Divider()
                    MarkdownView(markdown: document.text)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    NSDocumentController.shared.openDocument(nil)
                } label: {
                    Label("Open File", systemImage: "folder")
                }
                .help("Open an existing Markdown file  (⌘O)")

                Button {
                    NSApp.sendAction(Selector(("saveDocument:")), to: nil, from: nil)
                } label: {
                    Label("Save File", systemImage: "square.and.arrow.down")
                }
                .help("Save changes to the current file  (⌘S)")

                Button {
                    NSApp.sendAction(Selector(("saveDocumentAs:")), to: nil, from: nil)
                } label: {
                    Label("Save As", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Save the current file under a new name  (⇧⌘S)")

                Button {
                    NSApp.sendAction(Selector(("performClose:")), to: nil, from: nil)
                } label: {
                    Label("Close File", systemImage: "xmark.circle")
                }
                .help("Close the current document window  (⌘W)")

                Button {
                    NSApp.sendAction(Selector(("showWritingTools:")), to: nil, from: nil)
                } label: {
                    Label("Writing Tools", systemImage: "apple.intelligence")
                }
                .help("Open Apple Intelligence Writing Tools for the editor")
            }

            ToolbarItem {
                Picker("View Mode", selection: $mode) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

#Preview {
    ContentView(document: .constant(MD_EditorDocument()))
}
