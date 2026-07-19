import SwiftUI
import UIKit
import StoryViewerCore
import StoryViewerUIKit
import StoryViewerSwiftUI

struct ContentView: View {
    @State private var showSwiftUIViewer = false
    @State private var lastResult: String = "—"

    var body: some View {
        VStack(spacing: 24) {
            Text("StoryViewer Demo")
                .font(.title.bold())

            Button("SwiftUI flavor") {
                showSwiftUIViewer = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("swiftUIFlavorButton")

            Button("UIKit flavor") {
                presentUIKitViewer()
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
                onViewed: { id in print("SwiftUI viewed:", id) },
                onFinished: { viewedIds, clickedLink in
                    lastResult = "SwiftUI: viewed \(viewedIds.count), link: \(clickedLink?.absoluteString ?? "none")"
                    showSwiftUIViewer = false
                }
            )
        }
    }

    private func presentUIKitViewer() {
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
            onViewed: { id in print("UIKit viewed:", id) },
            onFinished: { viewedIds, clickedLink in
                lastResult = "UIKit: viewed \(viewedIds.count), link: \(clickedLink?.absoluteString ?? "none")"
            }
        )
    }
}
