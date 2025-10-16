//
//  ImageViewingTests.swift
//  Rideshare TrackerTests
//
//  Created by George Knaggs with Claude AI assistance on 10/3/25.
//

import XCTest
import SwiftUI
@testable import Rideshare_Tracker

final class ImageViewingTests: XCTestCase {

    var testShift: RideshareShift!
    var testExpense: ExpenseItem!
    var testImages: [UIImage]!

    override func setUpWithError() throws {
        // Create test shift with image attachments
        testShift = RideshareShift(
            startDate: Date(),
            startMileage: 100.0,
            startTankReading: 8.0,
            hasFullTankAtStart: true,
            gasPrice: 3.50,
            standardMileageRate: 0.67
        )

        // Add test image attachments
        let attachment1 = ImageAttachment(
            filename: "test1.jpg",
            type: .receipt,
            description: "Test receipt 1"
        )
        let attachment2 = ImageAttachment(
            filename: "test2.jpg",
            type: .damage,
            description: "Test vehicle photo"
        )
        testShift.imageAttachments = [attachment1, attachment2]

        // Create test expense with image attachments
        testExpense = ExpenseItem(
            date: Date(),
            category: .vehicle,
            description: "Test expense",
            amount: 25.0
        )
        testExpense.imageAttachments = [attachment1, attachment2]

        // Create test images
        testImages = [
            UIImage(systemName: "photo")!,
            UIImage(systemName: "camera")!,
            UIImage(systemName: "folder")!
        ]
    }

    func testImageViewingUtilitiesShowImageViewer() throws {
        // Test that ImageViewingUtilities correctly sets up image viewer state
        class TestStateHolder: @unchecked Sendable {
            var viewerImages: [UIImage] = []
            var viewerStartIndex: Int = 0
            var showingImageViewer: Bool = false
        }

        let state = TestStateHolder()

        let viewerImagesBinding = Binding(
            get: { state.viewerImages },
            set: { state.viewerImages = $0 }
        )
        let viewerStartIndexBinding = Binding(
            get: { state.viewerStartIndex },
            set: { state.viewerStartIndex = $0 }
        )
        let showingImageViewerBinding = Binding(
            get: { state.showingImageViewer },
            set: { state.showingImageViewer = $0 }
        )

        // Test with valid images and index
        let expectation = XCTestExpectation(description: "Image viewer should be shown")
        let expectedImageCount = testImages.count

        ImageViewingUtilities.showImageViewer(
            images: testImages,
            startIndex: 1,
            viewerImages: viewerImagesBinding,
            viewerStartIndex: viewerStartIndexBinding,
            showingImageViewer: showingImageViewerBinding
        )

        // Wait for async operation to complete (0.1 second delay in implementation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(state.viewerImages.count, expectedImageCount, "Viewer images should match input images")
            XCTAssertEqual(state.viewerStartIndex, 1, "Start index should be set correctly")
            XCTAssertTrue(state.showingImageViewer, "Image viewer should be shown")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testImageViewingUtilitiesWithEmptyImages() throws {
        // Test that ImageViewingUtilities handles empty image array correctly
        class TestStateHolder: @unchecked Sendable {
            var viewerImages: [UIImage] = []
            var viewerStartIndex: Int = 0
            var showingImageViewer: Bool = false
        }

        let state = TestStateHolder()

        let viewerImagesBinding = Binding(
            get: { state.viewerImages },
            set: { state.viewerImages = $0 }
        )
        let viewerStartIndexBinding = Binding(
            get: { state.viewerStartIndex },
            set: { state.viewerStartIndex = $0 }
        )
        let showingImageViewerBinding = Binding(
            get: { state.showingImageViewer },
            set: { state.showingImageViewer = $0 }
        )

        // Test with empty images array
        ImageViewingUtilities.showImageViewer(
            images: [],
            startIndex: 0,
            viewerImages: viewerImagesBinding,
            viewerStartIndex: viewerStartIndexBinding,
            showingImageViewer: showingImageViewerBinding
        )

        XCTAssertEqual(state.viewerImages.count, 0, "Viewer images should remain empty")
        XCTAssertFalse(state.showingImageViewer, "Image viewer should not be shown for empty images")
    }

    func testImageViewingUtilitiesWithInvalidIndex() throws {
        // Test that ImageViewingUtilities handles invalid index correctly
        class TestStateHolder: @unchecked Sendable {
            var viewerImages: [UIImage] = []
            var viewerStartIndex: Int = 0
            var showingImageViewer: Bool = false
        }

        let state = TestStateHolder()

        let viewerImagesBinding = Binding(
            get: { state.viewerImages },
            set: { state.viewerImages = $0 }
        )
        let viewerStartIndexBinding = Binding(
            get: { state.viewerStartIndex },
            set: { state.viewerStartIndex = $0 }
        )
        let showingImageViewerBinding = Binding(
            get: { state.showingImageViewer },
            set: { state.showingImageViewer = $0 }
        )

        // Test with invalid index (out of bounds)
        ImageViewingUtilities.showImageViewer(
            images: testImages,
            startIndex: 999,
            viewerImages: viewerImagesBinding,
            viewerStartIndex: viewerStartIndexBinding,
            showingImageViewer: showingImageViewerBinding
        )

        XCTAssertFalse(state.showingImageViewer, "Image viewer should not be shown for invalid index")
    }

    @MainActor func testImageViewingUtilitiesLoadImages() throws {
        // Test that ImageViewingUtilities correctly loads images from attachments
        // Note: This test would require actual image files in the Documents directory
        // For now, we'll test that the function doesn't crash and returns expected count

        let loadedImages = ImageViewingUtilities.loadImages(
            for: testShift.id,
            parentType: .shift,
            attachments: testShift.imageAttachments
        )

        // Since we don't have actual image files, loaded images will be empty
        // But the function should not crash and should return an array
        XCTAssertNotNil(loadedImages, "LoadImages should return a non-nil array")
        XCTAssertTrue(loadedImages.isEmpty, "LoadImages should return empty array when no files exist")
    }

    @MainActor func testImageAttachmentFileURL() throws {
        // Test that ImageAttachment generates correct file URLs
        let attachment = testShift.imageAttachments.first!

        let fileURL = attachment.fileURL(for: testShift.id, parentType: .shift)

        XCTAssertTrue(fileURL.path.contains(testShift.id.uuidString), "File URL should contain shift ID")
        XCTAssertTrue(fileURL.path.contains("shifts"), "File URL should contain shift parent type")
        XCTAssertTrue(fileURL.path.contains(attachment.filename), "File URL should contain filename")
    }

    @MainActor func testShiftImageAttachmentsIntegrity() throws {
        // Test that shift maintains image attachments correctly (the bug we fixed)
        let originalAttachmentCount = testShift.imageAttachments.count

        // Encode and decode the shift (simulating UserDefaults save/load)
        let encoder = JSONEncoder()
        let data = try encoder.encode(testShift)

        let decoder = JSONDecoder()
        let decodedShift = try decoder.decode(RideshareShift.self, from: data)

        XCTAssertEqual(decodedShift.imageAttachments.count, originalAttachmentCount,
                      "Decoded shift should preserve all image attachments")
        XCTAssertEqual(decodedShift.imageAttachments.first?.filename, testShift.imageAttachments.first?.filename,
                      "Decoded shift should preserve attachment filenames")
    }

    @MainActor func testExpenseImageAttachmentsIntegrity() throws {
        // Test that expense maintains image attachments correctly
        let originalAttachmentCount = testExpense.imageAttachments.count

        // Encode and decode the expense (simulating UserDefaults save/load)
        let encoder = JSONEncoder()
        let data = try encoder.encode(testExpense)

        let decoder = JSONDecoder()
        let decodedExpense = try decoder.decode(ExpenseItem.self, from: data)

        XCTAssertEqual(decodedExpense.imageAttachments.count, originalAttachmentCount,
                      "Decoded expense should preserve all image attachments")
        XCTAssertEqual(decodedExpense.imageAttachments.first?.filename, testExpense.imageAttachments.first?.filename,
                      "Decoded expense should preserve attachment filenames")
    }
}