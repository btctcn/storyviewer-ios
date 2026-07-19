import UIKit

/// Minimal async image fetcher with an in-memory cache, used by the UIKit flavor (the SwiftUI
/// flavor uses SwiftUI's own `AsyncImage`). Keeps the package free of a third-party image-loading
/// dependency, matching the Android library's "no dependency on a specific backend or framework"
/// stance.
public final class StoryImageLoader {
    public static let shared = StoryImageLoader()

    public enum LoaderError: Error {
        case invalidData
    }

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        let (data, _) = try await session.data(from: url)
        guard let image = UIImage(data: data) else { throw LoaderError.invalidData }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
