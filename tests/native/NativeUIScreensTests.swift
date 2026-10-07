import XCTest

@MainActor final class NativeUIScreensTests: XCTestCase {
    func testNativeScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "preview-settings", withExtension: "json"))
        let screens = ["main-light", "main-dark", "main-compact", "empty", "loading", "offline", "unpaired", "add", "pair", "details", "settings-video", "settings-audio", "settings-input", "settings-network", "settings-advanced"]
        for screen in screens {
            app.launchArguments = ["--design-preview", "--settings-fixture=" + fixture.path, screen == "main-light" ? "--light" : "--dark"]
            if screen == "main-compact" { app.launchArguments.append("--compact") }
            if !screen.hasPrefix("main-") { app.launchArguments.append("--preview-screen=" + screen) }
            app.launch()
            let window = app.windows[screen.hasPrefix("settings-") ? "native-settings" : "native-library"]
            XCTAssertTrue(window.waitForExistence(timeout: 10), "Missing native window: \(screen)")
            let target: XCUIElement
            if ["add", "pair", "details"].contains(screen) {
                target = window.sheets.firstMatch
                XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing sheet: \(screen)")
            } else { target = window }
            if screen.hasPrefix("settings-") {
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.025)).click()
            }
            // XCTest captures the composited UI, including system-owned glass.
            let screenshot = target.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = screen
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    func testAboutPanel() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--preview-screen=about", "--dark"]
        app.launch()
        XCTAssertTrue(app.windows["native-library"].waitForExistence(timeout: 10))
        let about = app.windows["native-about"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(about.links["GitHub Repository"].exists, "About GitHub link is not accessible")
        let attachment = XCTAttachment(screenshot: about.screenshot())
        attachment.name = "about-dark"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
}
