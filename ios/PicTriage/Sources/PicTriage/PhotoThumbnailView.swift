import SwiftUI
import Photos

/// Async thumbnail for a `PHAsset`, looked up by its `localIdentifier`.
/// Shows the diagonal-stripe placeholder while loading, and keeps showing it
/// if the asset can no longer be found (e.g. it was deleted since the last
/// scan) — there is no broken-image state, just the same placeholder the
/// prototype used everywhere.
struct PhotoThumbnailView: View {
    let localIdentifier: String
    var targetSize: CGSize = CGSize(width: 300, height: 300)
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            DiagonalStripes()
            if let image {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
        .task(id: "\(localIdentifier)@\(Int(targetSize.width))") {
            image = nil
            guard !localIdentifier.isEmpty else { return }
            image = await PhotoThumbnailLoader.shared.thumbnail(for: localIdentifier, targetSize: targetSize)
        }
    }
}

/// Loads and caches `PHAsset` thumbnails off the main actor so scrolling a
/// grid of photos doesn't spawn a flood of duplicate image requests.
actor PhotoThumbnailLoader {
    static let shared = PhotoThumbnailLoader()

    private let manager = PHCachingImageManager()
    private var cache: [String: UIImage] = [:]

    func thumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        let cacheKey = "\(localIdentifier)@\(Int(targetSize.width))"
        if let cached = cache[cacheKey] { return cached }

        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast

        let image: UIImage? = await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        if let image { cache[cacheKey] = image }
        return image
    }
}
