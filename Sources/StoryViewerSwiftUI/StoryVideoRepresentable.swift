import SwiftUI
import StoryViewerCore

/// Wraps `StoryViewerCore`'s `StoryVideoPlayerView` for SwiftUI, mirroring the Android Compose
/// flavor's `AndroidView` interop around the shared `VideoViewNoAudioFocus`.
struct StoryVideoRepresentable: UIViewRepresentable {
    let url: URL
    var isPaused: Bool
    var isMuted: Bool
    let onReady: (TimeInterval) -> Void

    func makeUIView(context: Context) -> StoryVideoPlayerView {
        let view = StoryVideoPlayerView()
        view.onReady = { [isMuted] duration in
            view.setVolume(isMuted ? 0 : 1)
            view.play()
            onReady(duration)
        }
        view.load(url: url)
        return view
    }

    func updateUIView(_ uiView: StoryVideoPlayerView, context: Context) {
        uiView.setVolume(isMuted ? 0 : 1)
        if isPaused {
            uiView.pause()
        } else {
            uiView.play()
        }
    }

    static func dismantleUIView(_ uiView: StoryVideoPlayerView, coordinator: ()) {
        uiView.stop()
    }
}
