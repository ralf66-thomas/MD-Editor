//
//  MD_EditorApp.swift
//  MD-Editor
//
//  Created by Ralf Thomas on 29.05.26.
//

import SwiftUI

@main
struct MD_EditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MD_EditorDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
