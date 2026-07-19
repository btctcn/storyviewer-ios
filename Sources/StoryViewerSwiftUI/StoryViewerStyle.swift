import SwiftUI

/// Visual style of `StoryViewerView` — the SwiftUI equivalent of the Android library's Compose
/// `StoryViewerStyle`. Pass a customized instance to match your app's branding.
public struct StoryViewerStyle {
    public var backgroundColor: Color
    public var progressTrackColor: Color
    public var progressFillColor: Color
    public var iconTintColor: Color
    public var iconBackgroundColor: Color
    public var watchButtonBackgroundColor: Color
    public var watchButtonTextColor: Color
    public var font: Font

    public init(
        backgroundColor: Color = .black,
        progressTrackColor: Color = Color.white.opacity(0.3),
        progressFillColor: Color = .white,
        iconTintColor: Color = Color(red: 0x29 / 255, green: 0x2B / 255, blue: 0x2C / 255),
        iconBackgroundColor: Color = Color.white.opacity(0.5),
        watchButtonBackgroundColor: Color = Color(red: 0xF2 / 255, green: 0xF6 / 255, blue: 0xFB / 255),
        watchButtonTextColor: Color = Color(red: 0x29 / 255, green: 0x2B / 255, blue: 0x2C / 255),
        font: Font = .system(size: 16)
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
