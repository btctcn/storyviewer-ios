import Foundation

/// Shared, UI-toolkit-agnostic state machine behind both the UIKit and SwiftUI story viewers:
/// current index, per-segment progress timing, pause/mute, viewed-id tracking and the
/// finish/"clicked link" contract. Both flavors drive the same instance-shaped logic instead of
/// duplicating it, the way the Android library's View and Compose flavors each reimplement it.
///
/// Default story duration is 5s for images; for videos it's the video's own duration, reported via
/// `videoReady(duration:)` once known.
@MainActor
public final class StoryViewerModel: ObservableObject {
    /// A request to animate segment `index`'s fill from its current value to `toValue` over
    /// `duration` seconds (0 = snap instantly). UI flavors observe this and animate however is
    /// idiomatic for their toolkit (`CABasicAnimation` / `withAnimation`).
    public struct SegmentAnimation: Equatable {
        public let token: Int
        public let index: Int
        public let toValue: Double
        public let duration: TimeInterval
    }

    public static let defaultImageDuration: TimeInterval = 5

    public let stories: [StoryItem]

    @Published public private(set) var currentIndex: Int = 0
    @Published public private(set) var isPaused: Bool = false
    @Published public var isMuted: Bool = true {
        didSet { onMuteChanged?(isMuted) }
    }
    /// Baseline fill for every segment right after entering a story: 1.0 before `currentIndex`,
    /// 0.0 at and after it. UI flavors snap their local progress state to this, then layer
    /// `segmentAnimation` on top.
    @Published public private(set) var progressBaseline: [Double] = []
    @Published public private(set) var segmentAnimation: SegmentAnimation?

    /// Called once per story the first time it's shown (not on revisits going back/forward).
    public var onViewed: (String) -> Void
    /// Called when the viewer should close: with every viewed story id, and the tapped link's URL
    /// if the watch button was used (nil otherwise).
    public var onFinished: (Set<String>, URL?) -> Void
    var onMuteChanged: ((Bool) -> Void)?

    private var viewedIds = Set<String>()
    private var fullDuration: TimeInterval?
    private var elapsed: TimeInterval = 0
    private var runStart: Date?
    private var advanceTask: Task<Void, Never>?
    private var animationToken = 0
    private var finished = false

    public init(
        stories: [StoryItem],
        startIndex: Int = 0,
        onViewed: @escaping (String) -> Void = { _ in },
        onFinished: @escaping (Set<String>, URL?) -> Void
    ) {
        self.stories = stories
        self.onViewed = onViewed
        self.onFinished = onFinished

        guard !stories.isEmpty else {
            finished = true
            onFinished([], nil)
            return
        }
        currentIndex = min(max(startIndex, 0), stories.count - 1)
        enterCurrentStory()
    }

    public var currentStory: StoryItem { stories[currentIndex] }

    // MARK: - Navigation

    public func next() { goTo(currentIndex + 1) }

    public func previous() { goTo(currentIndex - 1) }

    private func goTo(_ index: Int) {
        advanceTask?.cancel()
        guard stories.indices.contains(index) else {
            finish(clickedLink: nil)
            return
        }
        currentIndex = index
        enterCurrentStory()
    }

    private func enterCurrentStory() {
        isPaused = false
        fullDuration = nil
        elapsed = 0
        runStart = nil
        segmentAnimation = nil
        progressBaseline = stories.indices.map { $0 < currentIndex ? 1.0 : 0.0 }

        let story = currentStory
        if viewedIds.insert(story.id).inserted {
            onViewed(story.id)
        }

        if !story.isVideo {
            fullDuration = Self.defaultImageDuration
            startRun()
        }
        // For videos, wait for `videoReady(duration:)` before starting the timer.
    }

    // MARK: - Video lifecycle

    /// Call once the video player reports its duration and is ready to play.
    public func videoReady(duration: TimeInterval) {
        guard currentStory.isVideo else { return }
        fullDuration = max(duration, 1)
        if !isPaused {
            startRun()
        }
    }

    // MARK: - Playback controls

    public func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    /// Idempotent explicit pause, distinct from `togglePause()`. Intended for callers that need to
    /// suspend playback for a reason unrelated to the user's own pause/play button (e.g. the host
    /// app backgrounding or the screen locking) without flipping an already-paused state back to
    /// playing.
    public func pause() {
        guard !isPaused else { return }
        isPaused = true
        pauseRun()
    }

    /// Idempotent explicit resume, the counterpart to `pause()`. A caller that paused playback for
    /// its own reason (see `pause()`) should call this to undo exactly that, rather than
    /// `togglePause()` which would incorrectly resume a story the user had paused manually.
    public func resume() {
        guard isPaused else { return }
        isPaused = false
        startRun()
    }

    public func toggleMute() {
        isMuted.toggle()
    }

    public func watchTapped() {
        finish(clickedLink: currentStory.linkURL)
    }

    public func close() {
        finish(clickedLink: nil)
    }

    // MARK: - Timing

    private func currentElapsed() -> TimeInterval {
        guard let runStart else { return elapsed }
        return elapsed + Date().timeIntervalSince(runStart)
    }

    private func pauseRun() {
        if runStart != nil {
            elapsed = currentElapsed()
            runStart = nil
        }
        advanceTask?.cancel()
    }

    private func startRun() {
        guard !isPaused, let duration = fullDuration else { return }
        let remaining = max(duration - elapsed, 0)
        runStart = Date()
        animationToken += 1
        segmentAnimation = SegmentAnimation(token: animationToken, index: currentIndex, toValue: 1, duration: remaining)

        advanceTask?.cancel()
        let index = currentIndex
        advanceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(remaining, 0) * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            guard self.currentIndex == index else { return }
            self.next()
        }
    }

    private func finish(clickedLink: URL?) {
        guard !finished else { return }
        finished = true
        advanceTask?.cancel()
        onFinished(viewedIds, clickedLink)
    }
}
