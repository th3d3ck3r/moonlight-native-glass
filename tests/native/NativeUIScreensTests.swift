import XCTest

@MainActor final class NativeUIScreensTests: XCTestCase {
    func testOverlaySettings() throws {
        let app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "preview-settings", withExtension: "json"))
        app.launchArguments = ["--design-preview", "--settings-fixture=" + fixture.path, "--preview-screen=settings-overlay", "--dark"]
        app.launch()
        let window = app.windows["native-settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let label = window.staticTexts["Enable Optional Control Bar"]
        for _ in 0..<8 { if label.isHittable { break }; window.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(label.exists, "Optional controls setting missing")
        let shot = XCTAttachment(screenshot: window.screenshot()); shot.name = "settings-overlay"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    func testNativeScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "preview-settings", withExtension: "json"))
        let screens = ["main-light", "main-dark", "main-compact", "empty", "loading", "offline", "unpaired", "add", "pair", "details", "settings-video", "settings-audio", "settings-input", "settings-network", "settings-advanced", "settings-shortcuts"]
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
            if screen == "settings-video" {
                let resolution = window.popUpButtons["resolution-picker"]
                XCTAssertTrue(resolution.exists, "Resolution dropdown is missing")
                resolution.click()
                for label in ["720p", "1080p", "1440p", "4K"] {
                    XCTAssertTrue(app.menuItems[label].exists, "Missing resolution: \(label)")
                }
                app.menuItems["720p"].click()
                XCTAssertEqual(resolution.value as? String, "720p")
                resolution.click()
                app.menuItems["1080p"].click()
                XCTAssertEqual(resolution.value as? String, "1080p")
            }
            if screen == "settings-shortcuts" {
                XCTAssertTrue(window.staticTexts["Disconnect"].exists, "Shortcut bindings missing")
                XCTAssertFalse(window.staticTexts["Enable Optional Control Bar"].exists, "Overlay controls must have their own tab")
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

    func testMenuBarKeepsAppAvailable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--dark"]
        app.launch()
        let window = app.windows["native-library"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        // Close the library, rather than hiding the app or terminating it.
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(window.exists)
        let item = app.descendants(matching: .any)["native-status-item"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Menu bar icon disappeared after closing the window")
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Primary status click did not reopen the library without a stream window")
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        let menu = app.menus.containing(.menuItem, identifier: "Open Moonlight or Stream").firstMatch
        XCTAssertTrue(menu.menuItems["Open Moonlight or Stream"].waitForExistence(timeout: 5))
        XCTAssertTrue(menu.menuItems["Settings…"].exists)
        XCTAssertTrue(menu.menuItems["Quit Moonlight Native Glass"].exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "menu-bar"
        attachment.lifetime = .keepAlways
        add(attachment)
        menu.menuItems["Settings…"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(app.windows["native-settings"].waitForExistence(timeout: 5))
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        menu.menuItems["Quit Moonlight Native Glass"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let quit = NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue)
        expectation(for: quit, evaluatedWith: app)
        waitForExpectations(timeout: 10)
    }

    func testAboutPanel() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--preview-screen=about", "--dark"]
        app.launch()
        XCTAssertTrue(app.windows["native-library"].waitForExistence(timeout: 10))
        let about = app.dialogs["native-about"]
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(about.links["GitHub Repository"].exists, "About GitHub link is not accessible")
        let attachment = XCTAttachment(screenshot: about.screenshot())
        attachment.name = "about-dark"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
}
