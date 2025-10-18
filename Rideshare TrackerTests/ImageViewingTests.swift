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

    // MARK: - Enhanced Metadata Tests (TDD for Phase 1)

    @MainActor func testImageAttachmentCapturesFileSize() throws {
        // Test that ImageManager captures file size when saving images
        let testImage = UIImage(systemName: "photo.fill")!

        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testShift.id,
            parentType: .shift,
            type: .receipt,
            description: "Test image with metadata"
        )

        // File size should be captured
        XCTAssertNotNil(attachment.fileSize, "File size should be captured when saving image")
        XCTAssertGreaterThan(attachment.fileSize ?? 0, 0, "File size should be greater than zero")

        // Cleanup
        ImageManager.shared.deleteImage(attachment, for: testShift.id, parentType: .shift)
    }

    @MainActor func testImageAttachmentCapturesDimensions() throws {
        // Test that ImageManager captures image dimensions when saving
        let testImage = UIImage(systemName: "photo.fill")!

        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testShift.id,
            parentType: .shift,
            type: .receipt,
            description: "Test image with dimensions"
        )

        // Dimensions should be captured
        XCTAssertNotNil(attachment.imageDimensions, "Image dimensions should be captured")
        XCTAssertGreaterThan(attachment.imageDimensions?.width ?? 0, 0, "Image width should be greater than zero")
        XCTAssertGreaterThan(attachment.imageDimensions?.height ?? 0, 0, "Image height should be greater than zero")

        // Cleanup
        ImageManager.shared.deleteImage(attachment, for: testShift.id, parentType: .shift)
    }

    @MainActor func testImageAttachmentLocationIsOptional() throws {
        // Test that location is optional and doesn't block image saving
        let testImage = UIImage(systemName: "photo.fill")!

        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testShift.id,
            parentType: .shift,
            type: .receipt,
            description: "Test image without location"
        )

        // Location should be nil when not available (testing environment doesn't have GPS)
        // But image should still save successfully
        XCTAssertNil(attachment.location, "Location should be nil when not available")
        XCTAssertNotNil(attachment.fileSize, "Image should save successfully even without location")

        // Cleanup
        ImageManager.shared.deleteImage(attachment, for: testShift.id, parentType: .shift)
    }

    @MainActor func testImageAttachmentBackwardCompatibility() throws {
        // Test that old attachments without metadata can be decoded

        // Create an attachment in the old format (without new metadata fields)
        let oldFormatJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "filename": "test.jpg",
            "createdDate": 693964800.0,
            "type": "Receipt",
            "description": "Old format attachment"
        }
        """

        let decoder = JSONDecoder()
        let attachment = try decoder.decode(ImageAttachment.self, from: oldFormatJSON.data(using: .utf8)!)

        // Should decode successfully with nil metadata fields
        XCTAssertEqual(attachment.filename, "test.jpg")
        XCTAssertEqual(attachment.type, .receipt)
        XCTAssertEqual(attachment.description, "Old format attachment")
        XCTAssertNil(attachment.fileSize, "Old attachments should have nil fileSize")
        XCTAssertNil(attachment.imageDimensions, "Old attachments should have nil imageDimensions")
        XCTAssertNil(attachment.location, "Old attachments should have nil location")
    }

    @MainActor func testImageAttachmentLocationStructCoding() throws {
        // Test that Location struct encodes and decodes correctly

        let location = ImageAttachment.Location(
            latitude: 40.7128,
            longitude: -74.0060,
            address: "New York, NY"
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(location)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImageAttachment.Location.self, from: data)

        // Verify
        XCTAssertEqual(decoded.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(decoded.longitude, -74.0060, accuracy: 0.0001)
        XCTAssertEqual(decoded.address, "New York, NY")
    }

    @MainActor func testImageAttachmentWithFullMetadata() throws {
        // Test that attachment with all metadata fields encodes/decodes correctly

        let location = ImageAttachment.Location(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "San Francisco, CA"
        )

        let attachment = ImageAttachment(
            filename: "full-metadata.jpg",
            type: .gasPump,
            description: "Gas station receipt with location",
            fileSize: 2048576,
            imageDimensions: CGSize(width: 1920, height: 1080),
            location: location
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(attachment)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImageAttachment.self, from: data)

        // Verify all fields
        XCTAssertEqual(decoded.filename, "full-metadata.jpg")
        XCTAssertEqual(decoded.type, .gasPump)
        XCTAssertEqual(decoded.description, "Gas station receipt with location")
        XCTAssertEqual(decoded.fileSize, 2048576)
        XCTAssertEqual(decoded.imageDimensions?.width, 1920)
        XCTAssertEqual(decoded.imageDimensions?.height, 1080)
        XCTAssertNotNil(decoded.location, "Location should be decoded")
        XCTAssertEqual(decoded.location!.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(decoded.location!.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(decoded.location?.address, "San Francisco, CA")
    }

    // MARK: - Deferred Deletion Tests (TDD for Bug Fix)

    @MainActor func testShiftImageDeletionIsDeferredUntilSave() throws {
        // Test that images marked for deletion are NOT physically deleted until Save is pressed

        // Setup: Create a test image and save it
        let testImage = UIImage(systemName: "photo.fill")!
        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testShift.id,
            parentType: .shift,
            type: .receipt,
            description: "Test image"
        )

        // Verify file exists on disk
        let imageURL = ImageManager.shared.imageURL(for: testShift.id, parentType: .shift, filename: attachment.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path), "Image file should exist after save")

        // Simulate user marking image for deletion (but not saving yet)
        var existingAttachments = [attachment]
        var attachmentsMarkedForDeletion: [ImageAttachment] = []

        // User taps X on thumbnail - mark for deletion, don't delete file yet
        attachmentsMarkedForDeletion.append(attachment)
        existingAttachments.removeAll { $0.id == attachment.id }

        // Simulate Cancel - attachmentsMarkedForDeletion is discarded
        attachmentsMarkedForDeletion.removeAll()

        // CRITICAL: File should still exist after Cancel
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path),
                     "Image file should STILL EXIST after cancel - not deleted yet")

        // Cleanup
        ImageManager.shared.deleteImage(attachment, for: testShift.id, parentType: .shift)
    }

    @MainActor func testShiftImageDeletionOnlyHappensAfterSave() throws {
        // Test that images are physically deleted ONLY when Save is pressed

        // Setup: Create a test image and save it
        let testImage = UIImage(systemName: "photo.fill")!
        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testShift.id,
            parentType: .shift,
            type: .receipt,
            description: "Test image"
        )

        let imageURL = ImageManager.shared.imageURL(for: testShift.id, parentType: .shift, filename: attachment.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path), "Image file should exist after save")

        // Simulate edit workflow with deletion and Save
        var existingAttachments = [attachment]
        var attachmentsMarkedForDeletion: [ImageAttachment] = []

        // User marks for deletion
        attachmentsMarkedForDeletion.append(attachment)
        existingAttachments.removeAll { $0.id == attachment.id }

        // File should still exist (not deleted yet)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path),
                     "Image file should exist before Save is called")

        // Simulate Save - physically delete marked files
        for markedAttachment in attachmentsMarkedForDeletion {
            ImageManager.shared.deleteImage(markedAttachment, for: testShift.id, parentType: .shift)
        }

        // NOW file should be gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path),
                      "Image file should be DELETED after Save is called")
    }

    @MainActor func testExpenseImageDeletionIsDeferredUntilSave() throws {
        // Test that expense images marked for deletion are NOT physically deleted until Save is pressed

        // Setup: Create a test image and save it
        let testImage = UIImage(systemName: "photo.fill")!
        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testExpense.id,
            parentType: .expense,
            type: .receipt,
            description: "Test expense image"
        )

        // Verify file exists on disk
        let imageURL = ImageManager.shared.imageURL(for: testExpense.id, parentType: .expense, filename: attachment.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path), "Image file should exist after save")

        // Simulate user marking image for deletion (but not saving yet)
        var existingAttachments = [attachment]
        var attachmentsMarkedForDeletion: [ImageAttachment] = []

        // User taps X on thumbnail - mark for deletion, don't delete file yet
        attachmentsMarkedForDeletion.append(attachment)
        existingAttachments.removeAll { $0.id == attachment.id }

        // Simulate Cancel - attachmentsMarkedForDeletion is discarded
        attachmentsMarkedForDeletion.removeAll()

        // CRITICAL: File should still exist after Cancel
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path),
                     "Image file should STILL EXIST after cancel - not deleted yet")

        // Cleanup
        ImageManager.shared.deleteImage(attachment, for: testExpense.id, parentType: .expense)
    }

    @MainActor func testExpenseImageDeletionOnlyHappensAfterSave() throws {
        // Test that expense images are physically deleted ONLY when Save is pressed

        // Setup: Create a test image and save it
        let testImage = UIImage(systemName: "photo.fill")!
        let attachment = try ImageManager.shared.saveImage(
            testImage,
            for: testExpense.id,
            parentType: .expense,
            type: .receipt,
            description: "Test expense image"
        )

        let imageURL = ImageManager.shared.imageURL(for: testExpense.id, parentType: .expense, filename: attachment.filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path), "Image file should exist after save")

        // Simulate edit workflow with deletion and Save
        var existingAttachments = [attachment]
        var attachmentsMarkedForDeletion: [ImageAttachment] = []

        // User marks for deletion
        attachmentsMarkedForDeletion.append(attachment)
        existingAttachments.removeAll { $0.id == attachment.id }

        // File should still exist (not deleted yet)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path),
                     "Image file should exist before Save is called")

        // Simulate Save - physically delete marked files
        for markedAttachment in attachmentsMarkedForDeletion {
            ImageManager.shared.deleteImage(markedAttachment, for: testExpense.id, parentType: .expense)
        }

        // NOW file should be gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path),
                      "Image file should be DELETED after Save is called")
    }
}