import XCTest

/// Sample story order (see `SampleStories.swift`): [1: image+link, 2: image, 3: video, 4: image].
/// Story 1 carries the link so the watch-button assertions don't race the 5s image auto-advance
/// timer — they run the instant the viewer opens, no navigation required.
final class StoryViewerDemoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertLastResult(_ app: XCUIApplication, contains substring: String) {
        let label = app.staticTexts["lastResultLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertTrue(label.label.contains(substring), "Expected \"\(label.label)\" to contain \"\(substring)\"")
    }

    // MARK: - README screenshots

    /// Not a correctness test — drives the demo to capture the three README screenshots (feed,
    /// image viewer, video viewer) as XCTAttachments, matching the Android library's
    /// screenshots/{feed,viewer,viewer_video}.png.
    func testCaptureReadmeScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        attach(app, name: "screenshot-feed")

        app.buttons["storyCircle0"].tap()
        sleep(1)
        attach(app, name: "screenshot-viewer")

        // Named-element lookups inside the animating SwiftUI viewer are slow (see the note in
        // testSwiftUIWatchButtonReportsClickedLink) — tap the close button's known position.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.126)).tap()
        sleep(1)

        app.buttons["storyCircle2"].tap()
        sleep(2)
        attach(app, name: "screenshot-viewer-video")
    }

    // MARK: - SwiftUI flavor

    func testSwiftUIWatchButtonReportsClickedLink() throws {
        let app = XCUIApplication()
        app.launch()
        attach(app, name: "swiftui-01-home")

        app.buttons["swiftUIFlavorButton"].tap()
        // SwiftUI's `withAnimation`-driven progress bar keeps XCUITest's idle-detection busy for
        // the whole 5s of the animation, so a named-element `waitForExistence` lookup inside this
        // screen can itself take upwards of 10s to resolve — long enough for the real auto-advance
        // to fire and carry the viewer past story 1 before the lookup even returns. A raw
        // coordinate tap bypasses that lookup entirely and lands well within the 5s window, so tap
        // the watch button's known on-screen position directly instead of querying for it first.
        let watchButtonPosition = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        watchButtonPosition.tap()
        assertLastResult(app, contains: "storyviewer-ios")
        attach(app, name: "swiftui-02-after-watch-tap")
    }

    func testSwiftUINavigationAndClose() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["swiftUIFlavorButton"].tap()
        XCTAssertTrue(app.otherElements["storyViewer.swiftui.root"].waitForExistence(timeout: 10))

        let rightZone = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        rightZone.tap() // -> story 2 (or further: images auto-advance after 5s too)
        rightZone.tap()
        sleep(2)
        attach(app, name: "swiftui-04-video-story")

        // The auto-advance timer may have already run the viewer past the last story and closed
        // it on its own by now (see the file header) — only tap close if it's still open.
        if app.otherElements["storyViewer.swiftui.root"].exists {
            app.buttons["storyViewer.closeButton"].tap()
        }
        assertLastResult(app, contains: "link: none")
        attach(app, name: "swiftui-05-closed")
    }

    // MARK: - UIKit flavor

    func testUIKitWatchButtonReportsClickedLink() throws {
        let app = XCUIApplication()
        app.launch()
        attach(app, name: "uikit-01-home")

        app.buttons["uiKitFlavorButton"].tap()
        XCTAssertTrue(app.otherElements["storyViewer.uikit.root"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["storyViewer.watchButton"].waitForExistence(timeout: 5))
        attach(app, name: "uikit-02-story1-with-link")

        app.buttons["storyViewer.playPauseButton"].tap()
        attach(app, name: "uikit-03-paused")

        app.buttons["storyViewer.watchButton"].tap()
        assertLastResult(app, contains: "storyviewer-ios")
        attach(app, name: "uikit-04-after-watch-tap")
    }

    func testUIKitNavigationAndClose() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["uiKitFlavorButton"].tap()
        XCTAssertTrue(app.otherElements["storyViewer.uikit.root"].waitForExistence(timeout: 10))

        let rightZone = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        rightZone.tap() // -> story 2 (or further: images auto-advance after 5s too)
        rightZone.tap()
        sleep(2)
        attach(app, name: "uikit-05-video-story")

        // The auto-advance timer may have already run the viewer past the last story and closed
        // it on its own by now (see the file header) — only tap close if it's still open.
        if app.otherElements["storyViewer.uikit.root"].exists {
            app.buttons["storyViewer.closeButton"].tap()
        }
        assertLastResult(app, contains: "link: none")
        attach(app, name: "uikit-06-closed")
    }
}
