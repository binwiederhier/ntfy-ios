//
//  NotificationAttachmentImageView.swift
//  ntfy
//
//  Created by Alek Michelson on 5/11/26.
//

import SwiftUI

struct NotificationAttachmentImageView: View {
    @State private var imagePresentation: PresentedImage?

    let localFileUrl: URL?
    let isLoading: Bool

    var body: some View {
        Group {
            if let localFileUrl, let image = UIImage(contentsOfFile: localFileUrl.path) {
                renderedImage(image)
            } else if isLoading {
                loadingPlaceholder
            } else {
                failedPlaceholder
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(item: $imagePresentation) { presentedImage in
            AttachmentFullscreenImageView(image: presentedImage.image)
        }
    }

    private func renderedImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                imagePresentation = PresentedImage(image: image)
            }
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemFill))
            .frame(height: 160)
            .overlay {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading preview")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
    }

    private var failedPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemFill))
            .frame(height: 120)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
    }
}

private struct PresentedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct AttachmentFullscreenImageView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            ZoomableImageScrollView(image: image)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .padding()
            }
        }
    }
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4
        scrollView.minimumZoomScale = 1
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        scrollView.zoomScale = 1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
