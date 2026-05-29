//
//  MD_EditorDocument.swift
//  MD-Editor
//
//  Created by Ralf Thomas on 29.05.26.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated struct MD_EditorDocument: FileDocument {
    var text: String

    init(text: String = "Hello, world!") {
        self.text = text
    }

    static let readableContentTypes: [UTType] = [
        UTType(importedAs: "net.daringfireball.markdown"),
        .plainText
    ]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
