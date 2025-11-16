//
//  DocumentFile.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 9/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

// Document wrapper for file export - creates new document from file contents
// This shows "Save" instead of "Move" in the file exporter dialog
struct DocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }

    let data: Data

    init(url: URL) {
        // Read file contents into memory to create a new document (not move existing)
        self.data = (try? Data(contentsOf: url)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Create wrapper from data, not from existing file reference
        return FileWrapper(regularFileWithContents: data)
    }
}