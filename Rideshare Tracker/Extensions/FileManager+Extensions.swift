//
//  FileManager+Extensions.swift
//  Rideshare Tracker
//
//  Created by Claude on 11/6/25.
//

import Foundation
import ZIPFoundation

public extension FileManager {

    // MARK: - ZIP Archive Operations

    /// Create a ZIP archive from a directory
    /// - Parameters:
    ///   - sourceURL: Directory to compress
    ///   - destinationURL: Where to save the .zip file
    /// - Throws: Error if ZIP creation fails
    func zipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Check if source exists
        guard fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "FileManager+Extensions", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Source path does not exist: \(sourceURL.path)"])
        }

        // Remove destination if it exists
        if fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }

        // Use native coordinator for ZIP creation (iOS 14+)
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var copyError: Error?

        coordinator.coordinate(readingItemAt: sourceURL, options: [.forUploading], error: &coordinatorError) { zippedURL in
            do {
                try copyItem(at: zippedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let error = coordinatorError ?? copyError {
            throw error
        }
    }

    // MARK: - Directory Size Calculation
    // Note: unzipItem(at:to:) is provided by ZIPFoundation

    /// Calculate the size of a directory
    /// - Parameter url: Directory URL
    /// - Returns: Total size in bytes
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            totalSize += Int64(resourceValues.fileSize ?? 0)
        }

        return totalSize
    }
}
