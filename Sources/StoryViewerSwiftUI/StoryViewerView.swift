import SwiftUI
import StoryViewerCore

/// Full-screen story viewer — SwiftUI equivalent of the Android library's Compose
/// `StoryViewerScreen`: progress bars on top, timer-based auto-advance, tap left/right to
/// navigate, pause/mute, image and video support. Reports "story viewed" via `onViewed` and
/// finishes via `onFinished` with the set of viewed ids and the clicked link (if the watch button
/// was tapped).
public struct StoryViewerView: View {
    @StateObject private var model: StoryViewerModel
    private let style: StoryViewerStyle
    private let onFinished: (Set<String>, URL?) -> Void

    @State private var progress: [Double] = []

    public init(
        stories: [StoryItem],
        startIndex: Int = 0,
        style: StoryViewerStyle = .default,
        onViewed: @escaping (String) -> Void = { _ in },
        onFinished: @escaping (_ viewedIds: Set<String>, _ clickedLink: URL?) -> Void
    ) {
        self.style = style
        self.onFinished = onFinished
        _model = StateObject(wrappedValue: StoryViewerModel(
            stories: stories,
            startIndex: startIndex,
            onViewed: onViewed,
            onFinished: onFinished
        ))
    }

    public var body: some View {
        if model.stories.isEmpty {
            Color.clear
                .onAppear { onFinished([], nil) }
        } else {
            content
        }
    }

    private var content: some View {
        ZStack {
            style.backgroundColor
                .ignoresSafeArea()

            mediaView
                .id(model.currentStory.id)

            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.previous() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.next() }
            }

            VStack(spacing: 0) {
                progressBar
                controlsRow
                Spacer()
            }
            .padding(.top, 8)

            if let link = model.currentStory.linkURL {
                VStack {
                    Spacer()
                    watchButton(link: link)
                }
            }
        }
        .accessibilityIdentifier("storyViewer.swiftui.root")
        .onReceive(model.$progressBaseline) { baseline in
            progress = baseline
        }
        .onReceive(model.$segmentAnimation.compactMap { $0 }) { animation in
            guard progress.indices.contains(animation.index) else { return }
            if animation.duration > 0 {
                withAnimation(.linear(duration: animation.duration)) {
                    progress[animation.index] = animation.toValue
                }
            } else {
                progress[animation.index] = animation.toValue
            }
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        let story = model.currentStory
        if let videoURL = story.videoURL {
            StoryVideoRepresentable(
                url: StoryVideoCache.shared.cachedFile(for: videoURL) ?? videoURL,
                isPaused: model.isPaused,
                isMuted: model.isMuted,
                onReady: { duration in model.videoReady(duration: duration) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
        } else if let imageURL = story.imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
        } else {
            Color.clear
        }
    }

    private var progressBar: some View {
        HStack(spacing: 2) {
            ForEach(model.stories.indices, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(style.progressTrackColor)
                        Capsule()
                            .fill(style.progressFillColor)
                            .frame(width: geo.size.width * CGFloat(progress.indices.contains(index) ? progress[index] : 0))
                    }
                }
                .frame(height: 2)
            }
        }
        .padding(.horizontal, 12)
    }

    private var controlsRow: some View {
        HStack {
            roundButton(systemName: model.isPaused ? "play.fill" : "pause.fill", identifier: "storyViewer.playPauseButton") { model.togglePause() }
            roundButton(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", identifier: "storyViewer.muteButton") { model.toggleMute() }
            Spacer()
            roundButton(systemName: "xmark", identifier: "storyViewer.closeButton") { model.close() }
        }
        .padding(.horizontal, 8)
        .padding(.top, 16)
    }

    private func roundButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(style.iconTintColor)
                .frame(width: 44, height: 44)
                .background(style.iconBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier(identifier)
    }

    private func watchButton(link: URL) -> some View {
        Button(action: { model.watchTapped() }) {
            Text(model.currentStory.linkButtonText ?? "Watch")
                .font(style.font)
                .foregroundColor(style.watchButtonTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(style.watchButtonBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .accessibilityIdentifier("storyViewer.watchButton")
    }
}
