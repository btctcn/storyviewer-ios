import Foundation
import StoryViewerCore

enum SampleStories {
    static let all: [StoryItem] = [
        StoryItem(id: "1", imageURL: URL(string: "https://picsum.photos/seed/story1/1080/1920"), linkURL: URL(string: "https://www.apple.com")),
        StoryItem(id: "2", imageURL: URL(string: "https://picsum.photos/seed/story2/1080/1920")),
        StoryItem(id: "3", videoURL: URL(string: "https://www.w3schools.com/html/mov_bbb.mp4")),
        StoryItem(id: "4", imageURL: URL(string: "https://picsum.photos/seed/story4/1080/1920")),
    ]
}
