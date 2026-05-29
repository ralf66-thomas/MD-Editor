# MD-Editor

A lightweight, native **Markdown editor for macOS** built with SwiftUI. MD-Editor lets you open, edit, preview, and save Markdown documents with a clean three-mode interface — edit raw text, see a styled preview, or work in a side-by-side split view.

![Platform](https://img.shields.io/badge/platform-macOS-blue) ![Swift](https://img.shields.io/badge/Swift-5.0-orange) ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green)

---

## Features

- **Document-based app** — full integration with the macOS document system (open, save, save-as, close, autosave, version browsing, iCloud document support).
- **Three view modes** via a segmented control in the toolbar:
  - **Edit** — a monospaced plain-text editor for the raw Markdown source.
  - **Preview** — a styled, rendered view of the document.
  - **Split** — editor and live preview side by side.
- **Rich Markdown rendering** with support for:
  - Headers (levels 1–6, each with its own type scale)
  - **Bold**, *italic*, `inline code`, and [links](https://example.com)
  - Ordered and unordered lists, including nested indentation
  - Blockquotes
  - Fenced code blocks (monospaced, shaded background)
  - Thematic breaks (horizontal rules)
  - **Tables** with per-column alignment, header styling, and zebra-striped rows
- **Native file format support** — reads and writes `.md`, `.markdown`, `.mdown`, and `.mkd` files, plus plain text.
- **Apple Intelligence Writing Tools** integration for the editor.
- **Selectable text** in the preview for easy copying.

---

## Requirements

| | |
|---|---|
| **Platform** | macOS 26.5 or later |
| **Language** | Swift 5.0 |
| **UI Framework** | SwiftUI (with AppKit interop) |
| **Build tool** | Xcode |

---

## Getting Started

### Build & Run

1. Clone the repository and open the project:
   ```sh
   open MD-Editor.xcodeproj
   ```
2. Select the **MD-Editor** scheme.
3. Build and run (`⌘R`).

### Usage

When the app launches it opens a new untitled document (default content: `Hello, world!`). Use the toolbar to:

| Button | Action | Shortcut |
|---|---|---|
| 📁 Open File | Open an existing Markdown file | `⌘O` |
| 💾 Save File | Save changes to the current file | `⌘S` |
| 💾 Save As | Save the document under a new name | `⇧⌘S` |
| ✕ Close File | Close the current document window | `⌘W` |
| ✨ Writing Tools | Open Apple Intelligence Writing Tools | — |

Use the **segmented picker** on the right of the toolbar to switch between **Edit**, **Preview**, and **Split** modes.

---

## Project Structure

```
MD-Editor/
├── MD-Editor/
│   ├── MD_EditorApp.swift        # App entry point — defines the DocumentGroup scene
│   ├── MD_EditorDocument.swift   # FileDocument model — read/write Markdown & plain text
│   ├── ContentView.swift         # Main UI — view-mode switching and toolbar
│   ├── MarkdownView.swift        # Markdown parser and SwiftUI renderer
│   ├── Info.plist                # Document type & UTI declarations
│   └── Assets.xcassets/          # App icon and accent color
├── MD-EditorTests/               # Unit tests
├── MD-EditorUITests/             # UI tests
└── MD-Editor.xcodeproj/          # Xcode project
```

---

## Architecture

The app follows the standard SwiftUI **document-based app** pattern.

### `MD_EditorApp`
The `@main` entry point. It declares a `DocumentGroup` scene bound to `MD_EditorDocument`, which gives the app all standard macOS document behaviors (open panels, save dialogs, autosave, the window/tab model, and recent-documents tracking). Each document window hosts a `ContentView`.

### `MD_EditorDocument`
A `FileDocument` conforming type that holds the document's `text`. It declares its readable content types as the imported `net.daringfireball.markdown` UTI plus `.plainText`, decodes file contents as UTF-8 on read, and re-encodes the text to UTF-8 on write. The accompanying `Info.plist` registers the Markdown document type and its file extensions (`md`, `markdown`, `mdown`, `mkd`).

### `ContentView`
Owns the current `ViewMode` (`edit` / `preview` / `split`) as local state and renders the appropriate UI:
- **Edit** and **Split** use a `TextEditor` bound to `document.text` in a monospaced font.
- **Preview** and **Split** use `MarkdownView`.

The toolbar exposes file commands. Because SwiftUI's `DocumentGroup` does not surface these as direct API, the buttons bridge to AppKit by sending the standard responder-chain actions (`saveDocument:`, `saveDocumentAs:`, `performClose:`, `showWritingTools:`) via `NSApp.sendAction`, and open documents through `NSDocumentController`.

### `MarkdownView` — parsing & rendering
This is the heart of the rendering pipeline. Rather than depending on a third-party Markdown library, it builds on Foundation's built-in `AttributedString(markdown:)`.

1. **Parsing** (`MarkdownParser.parse`): The source string is parsed into an `AttributedString` using `.full` interpreted syntax. The parser then walks the attributed string's runs, inspecting each run's `PresentationIntent` to group runs into logical **blocks** (`MarkdownBlock`):
   - Consecutive runs with the same presentation intent are buffered together into a single paragraph/header/list-item/etc.
   - Block kind (header level, code block, blockquote, list item with ordinal & indent, thematic break) is derived from the intent's components in `makeBlock`.
   - If parsing throws, it gracefully falls back to rendering the raw source as a single paragraph.

2. **Tables** (`TableBuilder`): Table runs carry table/row/cell presentation components. A `TableBuilder` accumulates cells by row identity and column index, separating header rows from body rows, and emits a `.table` block carrying the column definitions (with alignment), header, and rows.

3. **Rendering** (`MarkdownBlockView` & `MarkdownTableView`): Each parsed block maps to a tailored SwiftUI view:
   - Headers get a size/weight scale by level.
   - Code blocks render in a monospaced font on a shaded, rounded background.
   - Blockquotes show a vertical accent bar with italic, secondary-colored text.
   - List items render a bullet (`•`) or ordinal marker with indentation.
   - Tables render via a `Grid` with header styling, zebra striping, per-column text alignment, and a rounded border.

   Blocks are laid out in a scrollable, left-aligned `VStack`, with text selection enabled.

---

## Testing

The project includes test targets:
- **MD-EditorTests** — unit tests.
- **MD-EditorUITests** — UI and launch tests.

Run all tests in Xcode with `⌘U`.

---

## Author

Created by **Ralf Thomas**.
