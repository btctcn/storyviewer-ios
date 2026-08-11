import UIKit
import Combine
import StoryViewerCore

/// Full-screen story viewer — UIKit equivalent of the Android library's View-flavor
/// `StoryViewerActivity`: progress bars on top, timer-based auto-advance, tap left/right to
/// navigate, pause/mute, image and video support.
///
/// The library has no dependency on any specific backend or DI framework: "story viewed" and
/// "link clicked" are reported back through plain closures, mirroring the Android View flavor's
/// `EXTRA_VIEWED_IDS`/`EXTRA_CLICKED_LINK` activity-result contract.
open class StoryViewerViewController: UIViewController {
    public typealias FinishHandler = (_ viewedIds: Set<String>, _ clickedLink: URL?) -> Void

    private let model: StoryViewerModel
    private let style: StoryViewerStyle
    private var cancellables = Set<AnyCancellable>()
    private var imageLoadTask: Task<Void, Never>?

    private let imageView = UIImageView()
    private var videoView: StoryVideoPlayerView?

    private let progressStack = UIStackView()
    private var segmentViews: [ProgressSegmentView] = []

    private let playPauseButton = UIButton(type: .system)
    private let muteButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let watchButton = UIButton(type: .system)

    public init(
        stories: [StoryItem],
        startIndex: Int = 0,
        style: StoryViewerStyle = .default,
        onViewed: @escaping (String) -> Void = { _ in },
        onFinished: @escaping FinishHandler
    ) {
        self.style = style
        self.model = StoryViewerModel(stories: stories, startIndex: startIndex, onViewed: onViewed, onFinished: onFinished)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Presents a full-screen story viewer modally from `presenter`, mirroring the Android
    /// library's `StoryViewerActivity.newIntent(...)` + `registerForActivityResult` launch
    /// pattern. If `stories` is empty, `onFinished` is called immediately and nothing is
    /// presented.
    public static func present(
        from presenter: UIViewController,
        stories: [StoryItem],
        startIndex: Int = 0,
        style: StoryViewerStyle = .default,
        animated: Bool = true,
        onViewed: @escaping (String) -> Void = { _ in },
        onFinished: @escaping FinishHandler
    ) {
        guard !stories.isEmpty else {
            onFinished([], nil)
            return
        }
        let viewer = StoryViewerViewController(
            stories: stories,
            startIndex: startIndex,
            style: style,
            onViewed: onViewed,
            onFinished: { viewedIds, clickedLink in
                presenter.dismiss(animated: true) {
                    onFinished(viewedIds, clickedLink)
                }
            }
        )
        presenter.present(viewer, animated: animated)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        guard !model.stories.isEmpty else { return }
        setUpLayout()
        bindModel()
        showCurrentStory()
        observeAppLifecycle()
    }

    deinit {
        imageLoadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - App lifecycle (screen lock / background)

    /// Suspends the timer and video playback when the app resigns active (screen lock, app
    /// switcher, incoming call, etc.) and resumes them on return — but only if this suspension is
    /// what paused it: a story the user had already paused manually stays paused after returning.
    private var isPausedBySystem = false

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleWillResignActive() {
        guard !model.isPaused else { return }
        isPausedBySystem = true
        model.pause()
    }

    @objc private func handleDidBecomeActive() {
        guard isPausedBySystem else { return }
        isPausedBySystem = false
        model.resume()
    }

    // MARK: - Layout

    private func setUpLayout() {
        view.backgroundColor = style.backgroundColor
        view.accessibilityIdentifier = "storyViewer.uikit.root"
        playPauseButton.accessibilityIdentifier = "storyViewer.playPauseButton"
        muteButton.accessibilityIdentifier = "storyViewer.muteButton"
        closeButton.accessibilityIdentifier = "storyViewer.closeButton"
        watchButton.accessibilityIdentifier = "storyViewer.watchButton"

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        progressStack.axis = .horizontal
        progressStack.spacing = 2
        progressStack.distribution = .fillEqually
        progressStack.translatesAutoresizingMaskIntoConstraints = false
        segmentViews = model.stories.map { _ in
            let segment = ProgressSegmentView()
            segment.trackColor = style.progressTrackColor
            segment.fillColor = style.progressFillColor
            segment.heightAnchor.constraint(equalToConstant: 2).isActive = true
            return segment
        }
        segmentViews.forEach(progressStack.addArrangedSubview)
        view.addSubview(progressStack)

        let controlsRow = UIStackView(arrangedSubviews: [
            makeRoundButton(playPauseButton, symbol: "pause.fill"),
            spacer(width: 8),
            makeRoundButton(muteButton, symbol: "speaker.slash.fill"),
            UIView(),
            makeRoundButton(closeButton, symbol: "xmark"),
        ])
        controlsRow.axis = .horizontal
        controlsRow.alignment = .center
        controlsRow.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(controlsRow)
        NSLayoutConstraint.activate([
            progressStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            progressStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            progressStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            controlsRow.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 16),
            controlsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            controlsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])

        watchButton.setTitle("Watch", for: .normal)
        watchButton.setTitleColor(style.watchButtonTextColor, for: .normal)
        watchButton.titleLabel?.font = style.font
        watchButton.backgroundColor = style.watchButtonBackgroundColor
        watchButton.layer.cornerRadius = 12
        watchButton.translatesAutoresizingMaskIntoConstraints = false
        watchButton.isHidden = true
        watchButton.addTarget(self, action: #selector(watchTapped), for: .touchUpInside)
        view.addSubview(watchButton)
        NSLayoutConstraint.activate([
            watchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            watchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            watchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            watchButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        playPauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
    }

    private func makeRoundButton(_ button: UIButton, symbol: String) -> UIView {
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = style.iconTintColor
        button.backgroundColor = style.iconBackgroundColor
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    private func spacer(width: CGFloat) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        return view
    }

    // MARK: - Model binding

    private func bindModel() {
        // `@Published` publishes from `willSet`, before its own backing storage is updated —
        // re-reading `model.currentIndex`/`model.currentStory` synchronously inside this sink
        // would see the OLD value, redisplaying the story we just left instead of the new one.
        // Deferring one runloop turn lets the model's property (and the rest of `goTo()`, e.g.
        // `enterCurrentStory()`) finish first.
        model.$currentIndex
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.showCurrentStory() }
            }
            .store(in: &cancellables)

        model.$progressBaseline
            .sink { [weak self] baseline in
                guard let self else { return }
                for (index, value) in baseline.enumerated() where self.segmentViews.indices.contains(index) {
                    self.segmentViews[index].setFraction(value, duration: 0)
                }
            }
            .store(in: &cancellables)

        model.$segmentAnimation
            .compactMap { $0 }
            .sink { [weak self] animation in
                guard let self, self.segmentViews.indices.contains(animation.index) else { return }
                self.segmentViews[animation.index].setFraction(animation.toValue, duration: animation.duration)
            }
            .store(in: &cancellables)

        model.$isPaused
            .sink { [weak self] isPaused in
                guard let self else { return }
                self.playPauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"), for: .normal)
                if isPaused { self.videoView?.pause() } else { self.videoView?.play() }
            }
            .store(in: &cancellables)

        model.$isMuted
            .sink { [weak self] isMuted in
                guard let self else { return }
                self.muteButton.setImage(UIImage(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"), for: .normal)
                self.videoView?.setVolume(isMuted ? 0 : 1)
            }
            .store(in: &cancellables)
    }

    // MARK: - Story presentation

    private func showCurrentStory() {
        NSLog("[StoryDebug] showCurrentStory index=\(model.currentIndex) id=\(model.currentStory.id) isVideo=\(model.currentStory.isVideo)")
        imageLoadTask?.cancel()
        videoView?.stop()
        videoView?.removeFromSuperview()
        videoView = nil

        let story = model.currentStory
        watchButton.isHidden = story.linkURL == nil

        if let videoURL = story.videoURL {
            imageView.isHidden = true
            imageView.image = nil
            let player = StoryVideoPlayerView()
            player.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(player, at: 0)
            NSLayoutConstraint.activate([
                player.topAnchor.constraint(equalTo: view.topAnchor),
                player.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                player.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                player.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            // `[weak player]`, not just `[weak self]` — `player` is stored in `player.onReady`
            // itself, so capturing it strongly here would retain it forever (the closure keeps
            // the view alive, the view keeps the closure alive), leaking its AVPlayer past
            // `showCurrentStory()` discarding `videoView` and letting the old story's audio keep
            // playing indefinitely underneath the new one.
            player.onReady = { [weak self, weak player] duration in
                guard let self, let player, self.model.currentStory.id == story.id else { return }
                player.setVolume(self.model.isMuted ? 0 : 1)
                player.play()
                self.model.videoReady(duration: duration)
            }
            videoView = player

            let localFile = StoryVideoCache.shared.cachedFile(for: videoURL)
            player.load(url: localFile ?? videoURL)
        } else {
            imageView.isHidden = false
            if let imageURL = story.imageURL {
                imageLoadTask = Task { [weak self] in
                    guard let self, let image = try? await StoryImageLoader.shared.image(for: imageURL) else { return }
                    guard !Task.isCancelled, self.model.currentStory.id == story.id else { return }
                    self.imageView.image = image
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func togglePause() { model.togglePause() }
    @objc private func toggleMute() { model.toggleMute() }
    @objc private func closeTapped() { model.close() }
    @objc private func watchTapped() { model.watchTapped() }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let x = recognizer.location(in: view).x
        if x < view.bounds.width / 2 {
            model.previous()
        } else {
            model.next()
        }
    }
}

extension StoryViewerViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
}
