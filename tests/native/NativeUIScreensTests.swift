import XCTest

@MainActor final class NativeUIScreensTests: XCTestCase {
    func testNativeScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "preview-settings", withExtension: "json"))
        let directory = URL(fileURLWithPath: "/tmp/moonlight-xctest-previews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let screens = ["main-light", "main-dark", "main-compact", "empty", "offline", "unpaired", "add", "pair", "details", "settings-video", "settings-audio", "settings-input", "settings-network", "settings-advanced"]
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
            // XCTest captures the composited UI, including system-owned glass.
            let screenshot = target.screenshot()
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(screen + ".png"))
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = screen
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
