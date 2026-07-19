import UIKit
import AVFoundation

/// Plays a video file full-bleed (center-cropped, like `ContentMode.scaleAspectFill`), with no
/// native transport controls.
///
/// Mirrors the Android library's `VideoViewNoAudioFocus`: the audio session is configured with
/// `.playback` + `.mixWithOthers` so story audio never interrupts or ducks whatever else the user
/// is already listening to, and is never silenced by the ringer switch — the same intent as the
/// Android view never requesting audio focus.
public final class StoryVideoPlayerView: UIView {
    public private(set) var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?

    /// Called once the item's duration is known, right before playback starts.
    public var onReady: ((TimeInterval) -> Void)?
    public var onFailure: ((Error?) -> Void)?

    public override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        Self.configureAudioSession()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspectFill
        Self.configureAudioSession()
    }

    private static func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
    }

    /// Loads and starts preparing `url` for playback. Call `setVolume` and `play()`/`pause()`
    /// once `onReady` fires.
    public func load(url: URL) {
        stop()
        let item = AVPlayerItem(url: url)
        currentItem = item
        let player = AVPlayer(playerItem: item)
        self.player = player
        playerLayer.player = player

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                let seconds = item.duration.seconds
                let duration = seconds.isFinite && seconds > 0 ? seconds : 1
                DispatchQueue.main.async { self.onReady?(duration) }
            case .failed:
                DispatchQueue.main.async { self.onFailure?(item.error) }
            default:
                break
            }
        }
    }

    public func play() { player?.play() }

    public func pause() { player?.pause() }

    public func setVolume(_ volume: Float) { player?.volume = volume }

    /// Stops playback and releases the player, mirroring `stopPlayback()`.
    public func stop() {
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        playerLayer.player = nil
        currentItem = nil
    }

    deinit {
        statusObservation?.invalidate()
    }
}
