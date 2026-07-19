// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "storyviewer-ios",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "StoryViewerCore", targets: ["StoryViewerCore"]),
        .library(name: "StoryViewerUIKit", targets: ["StoryViewerUIKit"]),
        .library(name: "StoryViewerSwiftUI", targets: ["StoryViewerSwiftUI"]),
    ],
    targets: [
        .target(
            name: "StoryViewerCore"
        ),
        .target(
            name: "StoryViewerUIKit",
            dependencies: ["StoryViewerCore"]
        ),
        .target(
            name: "StoryViewerSwiftUI",
            dependencies: ["StoryViewerCore"]
        ),
    ]
)
