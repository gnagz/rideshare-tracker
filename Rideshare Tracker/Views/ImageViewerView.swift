//
//  ImageViewerView.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 9/10/25.
//

import SwiftUI

struct ImageViewerView: View {
    let images: [UIImage]
    let startingIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    init(images: [UIImage], startingIndex: Int = 0, isPresented: Binding<Bool>) {
        self.images = images
        self.startingIndex = startingIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: startingIndex)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if !images.isEmpty && currentIndex < images.count {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<images.count, id: \.self) { index in
                            ZoomableImageView(image: images[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                } else {
                    // Debug: Show why content is not displaying
                    VStack {
                        Text("Debug Info:")
                            .foregroundColor(.white)
                        Text("Images count: \(images.count)")
                            .foregroundColor(.white)
                        Text("Current index: \(currentIndex)")
                            .foregroundColor(.white)
                        Text("Starting index: \(startingIndex)")
                            .foregroundColor(.white)
                    }
                }
            }
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareCurrentImage) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            debugMessage("ImageViewerView onAppear: images.count=\(images.count), startingIndex=\(startingIndex), currentIndex=\(currentIndex)")
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
    let sampleImages = [UIImage(systemName: "photo")!]
    
    return ImageViewerView(
        images: sampleImages,
        startingIndex: 0,
        isPresented: $isPresented
    )
}