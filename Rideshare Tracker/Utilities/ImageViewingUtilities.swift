//
//  ImageViewingUtilities.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 10/3/25.
//

import SwiftUI
import UIKit

/// Reusable utilities for image viewing functionality
/// Based on the working implementation from EditExpenseView
struct ImageViewingUtilities {

    /// Shows an image viewer with the provided images
    /// - Parameters:
    ///   - images: Array of UIImages to display
    ///   - startIndex: Index to start viewing from
    ///   - viewerImages: Binding to the viewer's image array
    ///   - viewerStartIndex: Binding to the viewer's start index
    ///   - showingImageViewer: Binding to control sheet presentation
    static func showImageViewer(
        images: [UIImage],
        startIndex: Int,
        viewerImages: Binding<[UIImage]>,
        viewerStartIndex: Binding<Int>,
        showingImageViewer: Binding<Bool>
    ) {
        debugMessage("ImageViewingUtilities showImageViewer: images.count=\(images.count), startIndex=\(startIndex)")

        if !images.isEmpty && startIndex < images.count {
            viewerImages.wrappedValue = images
            viewerStartIndex.wrappedValue = startIndex

            // Delay showing the sheet to allow state to propagate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingImageViewer.wrappedValue = true
            }

            debugMessage("ImageViewingUtilities showImageViewer: Set up viewer with \(images.count) images, starting at \(startIndex)")
        } else {
            debugMessage("ImageViewingUtilities showImageViewer: No images available or invalid index \(startIndex)")
        }
    }

    /// Loads images for a given parent ID and attachments
    /// - Parameters:
    ///   - parentID: UUID of the parent object
    ///   - parentType: Type of parent (shift or expense)
    ///   - attachments: Array of image attachments to load
    /// - Returns: Array of loaded UIImages
    @MainActor
    static func loadImages(
        for parentID: UUID,
        parentType: AttachmentParentType,
        attachments: [ImageAttachment]
    ) -> [UIImage] {
        debugMessage("ImageViewingUtilities loadImages: Loading \(attachments.count) attachments for \(parentType)")

        var loadedImages: [UIImage] = []

        for (index, attachment) in attachments.enumerated() {
            debugMessage("ImageViewingUtilities loadImages: Loading attachment \(index): \(attachment.filename)")

            if let image = ImageManager.shared.loadImage(
                for: parentID,
                parentType: parentType,
                filename: attachment.filename
            ) {
                loadedImages.append(image)
                debugMessage("ImageViewingUtilities loadImages: Successfully loaded \(attachment.filename)")
            } else {
                debugMessage("ImageViewingUtilities loadImages: Failed to load \(attachment.filename)")
            }
        }

        debugMessage("ImageViewingUtilities loadImages: Final count = \(loadedImages.count)")
        return loadedImages
    }
}

/// View modifier for common image viewer sheet presentation
struct ImageViewerSheet: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var images: [UIImage]
    let startIndex: Int

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if !images.isEmpty {
                    ImageViewerView(
                        images: $images,
                        startingIndex: startIndex,
                        isPresented: $isPresented
                    )
                }
            }
    }
}

extension View {
    /// Adds an image viewer sheet to the view
    func imageViewerSheet(
        isPresented: Binding<Bool>,
        images: Binding<[UIImage]>,
        startIndex: Int = 0
    ) -> some View {
        self.modifier(ImageViewerSheet(
            isPresented: isPresented,
            images: images,
            startIndex: startIndex
        ))
    }

    /// Adds camera and photo library picker sheets to the view
    func imagePickerSheets(
        showingCameraPicker: Binding<Bool>,
        showingPhotoLibraryPicker: Binding<Bool>,
        onImageSelected: @escaping (UIImage) -> Void
    ) -> some View {
        self
            .sheet(isPresented: showingCameraPicker) {
                ImagePickerView(
                    sourceType: .camera,
                    onImageSelected: { image in
                        onImageSelected(image)
                        showingCameraPicker.wrappedValue = false
                    },
                    onCancel: {
                        showingCameraPicker.wrappedValue = false
                    }
                )
            }
            .sheet(isPresented: showingPhotoLibraryPicker) {
                ImagePickerView(
                    sourceType: .photoLibrary,
                    onImageSelected: { image in
                        onImageSelected(image)
                        showingPhotoLibraryPicker.wrappedValue = false
                    },
                    onCancel: {
                        showingPhotoLibraryPicker.wrappedValue = false
                    }
                )
            }
    }
}

// MARK: - Photo Selection Button

/// Reusable button for adding photos with Camera/Photo Library choice
struct AddPhotoButton: View {
    @Binding var showingImageSourceActionSheet: Bool
    @Binding var showingCameraPicker: Bool
    @Binding var showingPhotoLibraryPicker: Bool

    var body: some View {
        Button(action: {
            showingImageSourceActionSheet = true
        }) {
            Label("Add Photos", systemImage: "camera.fill")
                .foregroundColor(.accentColor)
        }
        .accessibilityIdentifier("add_photo_button")
        .accessibilityLabel("Add Photos")
        .confirmationDialog("Add Photo", isPresented: $showingImageSourceActionSheet) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") {
                    showingCameraPicker = true
                }
            }
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                Button("Photo Library") {
                    showingPhotoLibraryPicker = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Photo Thumbnail View

/// Reusable photo thumbnail with view and delete buttons
struct PhotoThumbnailView: View {
    let image: UIImage
    let index: Int
    let onView: (Int) -> Void
    let onDelete: (Int) -> Void

    // Create a unique identifier for this image based on its hash
    private var imageIdentifier: String {
        String(image.hashValue)
    }

    var body: some View {
        // View button - tapping the thumbnail opens the viewer
        Button(action: {
            debugMessage("👁️ View button tapped - index: \(index), imageID: \(imageIdentifier)")
            onView(index)
        }) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1.0)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(alignment: .topTrailing) {
            // Delete button - positioned at top-trailing corner
            // Must be in overlay to be rendered on top and receive taps first
            Button(action: {
                debugMessage("❌ Delete button tapped - index: \(index), imageID: \(imageIdentifier)")
                onDelete(index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("delete_photo_\(index)")
            .offset(x: 6, y: -6)
        }
        .onAppear {
            debugMessage("📸 PhotoThumbnailView appeared - index: \(index), imageID: \(imageIdentifier)")
        }
    }
}

// MARK: - Photo Grid View

/// Reusable photo grid with thumbnails
struct PhotoGridView: View {
    let images: [UIImage]
    let onView: (Int) -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                PhotoThumbnailView(
                    image: image,
                    index: index,
                    onView: onView,
                    onDelete: onDelete
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Complete Photos Section

/// Complete reusable Photos section with button, grid, and all state management
/// Handles both simple (new photos only) and edit scenarios (existing + new photos)
struct PhotosSection: View {
    // New photos (in memory)
    @Binding var photoImages: [UIImage]

    // Optional: Existing photos (for edit scenarios)
    var existingImages: Binding<[UIImage]>?

    // Optional: Callback for deleting existing photos (for edit scenarios)
    var onDeleteExisting: ((Int) -> Void)?

    // Picker state
    @Binding var showingImageSourceActionSheet: Bool
    @Binding var showingCameraPicker: Bool
    @Binding var showingPhotoLibraryPicker: Bool

    // Viewer state
    @Binding var showingImageViewer: Bool
    @Binding var viewerImages: [UIImage]
    @Binding var viewerStartIndex: Int

    // Computed: all images combined (existing + new)
    private var allImages: [UIImage] {
        var images: [UIImage] = []
        if let existing = existingImages?.wrappedValue {
            images.append(contentsOf: existing)
        }
        images.append(contentsOf: photoImages)
        return images
    }

    private var existingCount: Int {
        existingImages?.wrappedValue.count ?? 0
    }

    var body: some View {
        Section("Photos") {
            AddPhotoButton(
                showingImageSourceActionSheet: $showingImageSourceActionSheet,
                showingCameraPicker: $showingCameraPicker,
                showingPhotoLibraryPicker: $showingPhotoLibraryPicker
            )

            if !allImages.isEmpty {
                let newCount = photoImages.count

                if existingCount > 0 {
                    Text("\(existingCount) existing, \(newCount) new photo\(newCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(newCount) photo\(newCount == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !allImages.isEmpty {
                PhotoGridView(
                    images: allImages,
                    onView: { index in
                        debugMessage("PhotosSection onView: index=\(index), showingImageViewer=\(showingImageViewer), allImages.count=\(allImages.count)")
                        guard !showingImageViewer else {
                            debugMessage("PhotosSection onView: Guard blocked - viewer already showing")
                            return
                        }
                        ImageViewingUtilities.showImageViewer(
                            images: allImages,
                            startIndex: index,
                            viewerImages: $viewerImages,
                            viewerStartIndex: $viewerStartIndex,
                            showingImageViewer: $showingImageViewer
                        )
                    },
                    onDelete: { index in
                        guard index < allImages.count else { return }

                        if index < existingCount {
                            // Deleting existing photo
                            onDeleteExisting?(index)
                        } else {
                            // Deleting new photo
                            let newIndex = index - existingCount
                            photoImages.remove(at: newIndex)
                        }
                    }
                )
            }
        }
        .accessibilityIdentifier("Photos")
    }
}

// MARK: - UIImagePickerController Wrapper

/// UIImagePickerController wrapper for camera and photo library access
struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}