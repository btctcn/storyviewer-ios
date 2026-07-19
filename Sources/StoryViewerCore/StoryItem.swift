import Foundation

/// A single story: an image or a video, with an optional call-to-action link.
///
/// Mirrors the Android library's `StoryItem` (id, imageUrl, videoUrl, linkUrl) so hosts can share
/// the same backend model shape across platforms.
public struct StoryItem: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let imageURL: URL?
    public let videoURL: URL?
    public let linkURL: URL?

    public init(id: String, imageURL: URL? = nil, videoURL: URL? = nil, linkURL: URL? = nil) {
        self.id = id
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.linkURL = linkURL
    }

    public var isVideo: Bool { videoURL != nil }
}
