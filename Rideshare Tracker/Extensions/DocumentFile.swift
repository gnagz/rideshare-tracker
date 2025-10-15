//
//  DocumentFile.swift
//  Rideshare Tracker
//
//  Created by Claude AI on 9/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

// Document wrapper for file export
struct DocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        // This shouldn't be called for our use case
        throw CocoaError(.fileReadCorruptFile)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: url)
    }
}