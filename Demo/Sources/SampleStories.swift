import Foundation
import StoryViewerCore

/// Images/video are bundled resources (not remote URLs), so the demo works fully offline — in a
/// real app `StoryItem.imageURL`/`videoURL` would just as well be regular https:// URLs; the
/// player/loader don't care as long as the URL resolves to a loadable source. Same source assets
/// as the Android library's sample module, for a like-for-like screenshot comparison.
enum SampleStories {
    static let all: [StoryItem] = [
        StoryItem(
            id: "1",
            imageURL: bundledURL("sample_photo_1", "png"),
            linkURL: URL(string: "https://github.com/btctcn/storyviewer-ios")
        ),
        StoryItem(
            id: "2",
            imageURL: bundledURL("sample_photo_2", "png")
        ),
        StoryItem(
            id: "3",
            imageURL: bundledURL("sample_photo_3", "png"),
            videoURL: bundledURL("sample_video", "mp4"),
            linkURL: URL(string: "https://github.com/btctcn/storyviewer-ios")
        ),
        StoryItem(
            id: "4",
            imageURL: bundledURL("sample_photo_4", "png")
        ),
    ]

    private static func bundledURL(_ name: String, _ ext: String) -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            fatalError("Missing bundled resource \(name).\(ext)")
        }
        return url
    }
}
