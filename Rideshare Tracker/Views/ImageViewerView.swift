//
//  ImageViewerView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/10/25.
//

import SwiftUI

struct ImageViewerView: View {
    @Binding var images: [UIImage]
    let startingIndex: Int
    @Binding var isPresented: Bool

    // Optional: Image attachments for metadata display/editing
    var attachments: [ImageAttachment]?
    var isEditMode: Bool = false
    var onSaveAttachment: ((Int, ImageAttachment) -> Void)?

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingMetadata: Bool = false

    init(images: Binding<[UIImage]>, startingIndex: Int = 0, isPresented: Binding<Bool>, attachments: [ImageAttachment]? = nil, isEditMode: Bool = false, onSaveAttachment: ((Int, ImageAttachment) -> Void)? = nil) {
        self._images = images
        self.startingIndex = startingIndex
        self._isPresented = isPresented
        self.attachments = attachments
        self.isEditMode = isEditMode
        self.onSaveAttachment = onSaveAttachment
        self._currentIndex = State(initialValue: startingIndex)
    }

    private var currentAttachment: ImageAttachment? {
        // If attachments provided and valid, use them
        if let attachments = attachments, currentIndex < attachments.count {
            return attachments[currentIndex]
        }

        // Fallback: Create temporary attachment from images array
        if currentIndex < images.count {
            return ImageAttachment(
                filename: "photo_\(currentIndex + 1).jpg",
                type: .other,
                description: nil,
                dateAttached: Date()
            )
        }

        return nil
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image display area
                ZStack {
                    Color.black

                    if !images.isEmpty && currentIndex < images.count {
                        TabView(selection: $currentIndex) {
                            ForEach(0..<images.count, id: \.self) { index in
                                ZoomableImageView(image: images[index])
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                    }
                }

                // Metadata section (if attachment data available)
                if currentAttachment != nil, currentIndex < images.count {
                    MetadataSection(
                        attachment: currentAttachment!,
                        currentImage: images[currentIndex],
                        isEditMode: isEditMode,
                        isExpanded: $showingMetadata,
                        onSave: { updatedAttachment in
                            onSaveAttachment?(currentIndex, updatedAttachment)
                        }
                    )
                    .id(currentIndex)  // Force refresh when photo index changes (but not when metadata changes)
                    .background(Color(.systemBackground))
                }
            }
            .ignoresSafeArea(edges: currentAttachment == nil ? .all : .top)
            .navigationTitle("Photo \(currentIndex + 1) of \(images.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }

                // Previous photo button
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Button(action: {
                            if currentIndex > 0 {
                                currentIndex -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .opacity(currentIndex > 0 ? 1.0 : 0.3)
                        }
                        .disabled(currentIndex == 0)
                        .accessibilityIdentifier("previous_photo_button")

                        Text("Photo \(currentIndex + 1) of \(images.count)")
                            .foregroundColor(.white)
                            .font(.headline)

                        Button(action: {
                            if currentIndex < images.count - 1 {
                                currentIndex += 1
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                                .opacity(currentIndex < images.count - 1 ? 1.0 : 0.3)
                        }
                        .disabled(currentIndex == images.count - 1)
                        .accessibilityIdentifier("next_photo_button")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareCurrentImage) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            debugMessage("ImageViewerView onAppear: images.count=\(images.count), startingIndex=\(startingIndex), currentIndex=\(currentIndex), attachments=\(attachments?.count ?? 0), currentAttachment=\(currentAttachment != nil ? "YES" : "NO")")
        }
    }
    
    private func shareCurrentImage() {
        guard currentIndex < images.count else { return }
        
        let activityView = UIActivityViewController(
            activityItems: [images[currentIndex]],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // For iPad - set popover presentation
            if let popover = activityView.popoverPresentationController {
                popover.sourceView = window.rootViewController?.view
                popover.sourceRect = CGRect(x: window.bounds.width - 50, y: 100, width: 0, height: 0)
            }
            
            window.rootViewController?.present(activityView, animated: true)
        }
    }
}

struct MetadataSection: View {
    let attachment: ImageAttachment
    let currentImage: UIImage
    let isEditMode: Bool
    @Binding var isExpanded: Bool
    let onSave: (ImageAttachment) -> Void

    @State private var editedType: AttachmentType
    @State private var editedDescription: String

    // KNOWN ISSUE: Metadata doesn't update when swiping between photos in TabView
    // The MetadataSection is created once with initial attachment data and doesn't
    // react to changes in currentIndex. Need to add .id() or .onChange() to force refresh.

    init(attachment: ImageAttachment, currentImage: UIImage, isEditMode: Bool, isExpanded: Binding<Bool>, onSave: @escaping (ImageAttachment) -> Void) {
        self.attachment = attachment
        self.currentImage = currentImage
        self.isEditMode = isEditMode
        self._isExpanded = isExpanded
        self.onSave = onSave
        self._editedType = State(initialValue: attachment.type)
        self._editedDescription = State(initialValue: attachment.description ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible header
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Photo Information")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .foregroundColor(.primary)
            .accessibilityIdentifier("photo_information_button")

            // Metadata content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Type field (editable in edit mode, locked for system-generated)
                    HStack {
                        Text("Type:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)

                        if isEditMode && !attachment.type.isSystemGenerated {
                            Picker("Type", selection: $editedType) {
                                ForEach(AttachmentType.allCases.filter { !$0.isSystemGenerated }, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("type_picker")
                            .onChange(of: editedType) { oldValue, newValue in
                                saveChanges()
                            }
                        } else {
                            HStack {
                                Image(systemName: attachment.type.systemImage)
                                Text(attachment.type.displayName)
                            }
                            if attachment.type.isSystemGenerated {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .accessibilityIdentifier("type_lock_icon")
                            }
                        }
                        Spacer()
                    }

                    // Description field (always editable in edit mode)
                    HStack(alignment: .top) {
                        Text("Description:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)

                        if isEditMode {
                            TextField("Add description", text: $editedDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                                .accessibilityIdentifier("description_text_field")
                                .onChange(of: editedDescription) { oldValue, newValue in
                                    saveChanges()
                                }
                        } else {
                            Text(attachment.description ?? "No description")
                                .foregroundColor(attachment.description == nil ? .secondary : .primary)
                        }
                        Spacer()
                    }

                    Divider()

                    // Read-only metadata
                    MetadataRow(label: "Date Attached", value: formatDate(attachment.dateAttached))
                }
                .padding()
            }
        }
    }

    private func saveChanges() {
        let updated = ImageAttachment(
            id: attachment.id,  // Preserve original ID for matching in parent view
            filename: attachment.filename,
            type: editedType,
            description: editedDescription.isEmpty ? nil : editedDescription,
            dateAttached: attachment.dateAttached
        )
        onSave(updated)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .animation(.interactiveSpring(), value: scale)
                .animation(.interactiveSpring(), value: offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.5, min(value, 10.0))
                            }
                            .onEnded { value in
                                // Snap to reasonable scale levels
                                if scale < 1.0 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } else if scale > 5.0 {
                                    scale = 5.0
                                }
                            },

                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { value in
                                lastOffset = offset

                                // Simple bounds checking - allow generous panning
                                let maxOffset: CGFloat = geometry.size.width * scale * 0.5

                                let constrainedOffsetX = max(-maxOffset, min(maxOffset, offset.width))
                                let constrainedOffsetY = max(-maxOffset, min(maxOffset, offset.height))

                                if constrainedOffsetX != offset.width || constrainedOffsetY != offset.height {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        offset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
                                        lastOffset = offset
                                    }
                                }
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    // Double tap to zoom
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if scale > 1.5 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 3.0
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var sampleImages = [UIImage(systemName: "photo")!]

    return ImageViewerView(
        images: $sampleImages,
        startingIndex: 0,
        isPresented: $isPresented
    )
}