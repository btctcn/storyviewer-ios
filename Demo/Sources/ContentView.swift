import SwiftUI
import UIKit
import StoryViewerCore
import StoryViewerUIKit
import StoryViewerSwiftUI

struct ContentView: View {
    @State private var showSwiftUIViewer = false
    @State private var swiftUIStartIndex = 0
    @State private var lastResult: String = "—"

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("StoryViewer Demo")
                    .font(.title.bold())
                Text("Tap a circle to open the story viewer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(Array(SampleStories.all.enumerated()), id: \.offset) { index, story in
                    Button {
                        swiftUIStartIndex = index
                        showSwiftUIViewer = true
                    } label: {
                        StoryCircle(story: story)
                    }
                    .accessibilityIdentifier("storyCircle\(index)")
                }
            }

            Button("SwiftUI flavor") {
                swiftUIStartIndex = 0
                showSwiftUIViewer = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("swiftUIFlavorButton")

            Button("UIKit flavor") {
                presentUIKitViewer(startIndex: 0)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("uiKitFlavorButton")

            Text("Last result: \(lastResult)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier("lastResultLabel")
        }
        .padding()
        .fullScreenCover(isPresented: $showSwiftUIViewer) {
            StoryViewerView(
                stories: SampleStories.all,
                startIndex: swiftUIStartIndex,
                onViewed: { id in print("SwiftUI viewed:", id) },
                onFinished: { viewedIds, clickedLink in
                    lastResult = "SwiftUI: viewed \(viewedIds.count), link: \(clickedLink?.absoluteString ?? "none")"
                    showSwiftUIViewer = false
                }
            )
        }
    }

    private func presentUIKitViewer(startIndex: Int) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        StoryViewerViewController.present(
            from: presenter,
            stories: SampleStories.all,
            startIndex: startIndex,
            onViewed: { id in print("UIKit viewed:", id) },
            onFinished: { viewedIds, clickedLink in
                lastResult = "UIKit: viewed \(viewedIds.count), link: \(clickedLink?.absoluteString ?? "none")"
            }
        )
    }
}

private struct StoryCircle: View {
    let story: StoryItem

    var body: some View {
        AsyncImage(url: story.imageURL) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Color(.systemGray5)
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(red: 0x3D / 255, green: 0x7B / 255, blue: 0xFF / 255), lineWidth: 2))
    }
}
