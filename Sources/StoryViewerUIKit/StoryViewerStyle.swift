import UIKit

/// Visual style of `StoryViewerViewController` — the UIKit equivalent of the Android library's
/// `Theme.StoryViewer` attributes (View flavor) / `StoryViewerStyle` (Compose flavor). Pass a
/// customized instance to match your app's branding.
public struct StoryViewerStyle {
    public var backgroundColor: UIColor
    public var progressTrackColor: UIColor
    public var progressFillColor: UIColor
    public var iconTintColor: UIColor
    public var iconBackgroundColor: UIColor
    public var watchButtonBackgroundColor: UIColor
    public var watchButtonTextColor: UIColor
    public var font: UIFont

    public init(
        backgroundColor: UIColor = .black,
        progressTrackColor: UIColor = UIColor.white.withAlphaComponent(0.3),
        progressFillColor: UIColor = .white,
        iconTintColor: UIColor = UIColor(red: 0x29 / 255, green: 0x2B / 255, blue: 0x2C / 255, alpha: 1),
        iconBackgroundColor: UIColor = UIColor.white.withAlphaComponent(0.5),
        watchButtonBackgroundColor: UIColor = UIColor(red: 0xF2 / 255, green: 0xF6 / 255, blue: 0xFB / 255, alpha: 1),
        watchButtonTextColor: UIColor = UIColor(red: 0x29 / 255, green: 0x2B / 255, blue: 0x2C / 255, alpha: 1),
        font: UIFont = .systemFont(ofSize: 16)
    ) {
        self.backgroundColor = backgroundColor
        self.progressTrackColor = progressTrackColor
        self.progressFillColor = progressFillColor
        self.iconTintColor = iconTintColor
        self.iconBackgroundColor = iconBackgroundColor
        self.watchButtonBackgroundColor = watchButtonBackgroundColor
        self.watchButtonTextColor = watchButtonTextColor
        self.font = font
    }

    public static let `default` = StoryViewerStyle()
}
