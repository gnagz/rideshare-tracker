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
            currentIndex = startingIndex
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
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                            .onEnded { value in
                                // Constrain scale
                                scale = max(1.0, min(scale, 5.0))
                                
                                // Reset offset if zoomed out completely
                                if scale <= 1.0 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
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
                                if scale > 1.0 {
                                    lastOffset = offset
                                    
                                    // Constrain offset to keep image visible
                                    let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                    let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                    
                                    let constrainedOffsetX = max(-maxOffsetX, min(maxOffsetX, offset.width))
                                    let constrainedOffsetY = max(-maxOffsetY, min(maxOffsetY, offset.height))
                                    
                                    if constrainedOffsetX != offset.width || constrainedOffsetY != offset.height {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            offset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
                                            lastOffset = offset
                                        }
                                    }
                                }
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    // Double tap to zoom
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }
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