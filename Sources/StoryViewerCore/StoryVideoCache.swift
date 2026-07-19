import Foundation
import CryptoKit

/// On-disk cache for story videos: stories change rarely, so the first N stories' videos are
/// downloaded in the background right after the feed loads, so opening the viewer doesn't wait on
/// network buffering. The cache directory always holds only the videos from the LAST `prefetch()`
/// call — stale files are deleted, no separate LRU is needed since the set is small (N files).
///
/// Mirrors the Android library's `StoryVideoCache`.
public final class StoryVideoCache {
    public static let shared = StoryVideoCache()

    private let cacheDir: URL
    private let session: URLSession
    private let queue = DispatchQueue(label: "dev.btctcn.storyviewer.videocache")
    private let fileManager = FileManager.default

    public init(session: URLSession = .shared) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDir = caches.appendingPathComponent("story_videos", isDirectory: true)
        self.session = session
    }

    /// The local file for this URL, if the video is already cached on disk.
    public func cachedFile(for url: URL) -> URL? {
        let file = cacheDir.appendingPathComponent(fileName(for: url))
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else {
            return nil
        }
        return file
    }

    /// Downloads the videos at `urls` in the background and deletes anything from the cache that
    /// isn't in this list. `onDownloadError` is an optional callback for reporting download errors
    /// to the host's own analytics.
    public func prefetch(urls: [URL], onDownloadError: ((Error) -> Void)? = nil) {
        var seen = Set<URL>()
        let distinctURLs = urls.filter { seen.insert($0).inserted }
        guard !distinctURLs.isEmpty else { return }
        queue.async { [weak self] in
            self?.performPrefetch(distinctURLs, onDownloadError: onDownloadError)
        }
    }

    private func performPrefetch(_ urls: [URL], onDownloadError: ((Error) -> Void)?) {
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        let keepNames = Set(urls.map { fileName(for: $0) })
        if let existing = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in existing where !keepNames.contains(file.lastPathComponent) {
                try? fileManager.removeItem(at: file)
            }
        }
        for url in urls {
            downloadIfMissing(url, onDownloadError: onDownloadError)
        }
    }

    private func downloadIfMissing(_ url: URL, onDownloadError: ((Error) -> Void)?) {
        let target = cacheDir.appendingPathComponent(fileName(for: url))
        if let size = try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
            return
        }
        let tmp = cacheDir.appendingPathComponent(fileName(for: url) + ".tmp")
        let semaphore = DispatchSemaphore(value: 0)
        let task = session.downloadTask(with: url) { [weak self] location, response, error in
            defer { semaphore.signal() }
            guard let self else { return }
            if let error {
                onDownloadError?(error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode,
                  let location else {
                return
            }
            do {
                try? self.fileManager.removeItem(at: tmp)
                try self.fileManager.moveItem(at: location, to: tmp)
                try? self.fileManager.removeItem(at: target)
                try self.fileManager.moveItem(at: tmp, to: target)
            } catch {
                onDownloadError?(error)
                try? self.fileManager.removeItem(at: tmp)
            }
        }
        task.resume()
        semaphore.wait()
    }

    private func fileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hex).mp4"
    }
}
