import XCTest

@MainActor final class NativeUIScreensTests: XCTestCase {
    func testOverlaySettings() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "preview-settings", withExtension: "json"))
        app.launchArguments = ["--design-preview", "--settings-fixture=" + fixture.path, "--preview-screen=settings-overlay", "--dark"]
        app.launch()
        let window = app.windows["native-settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        // As in the other Settings captures, activate the window before the
        // first control click; AppKit otherwise uses that click for activation.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.025)).click()
        let customization = window.disclosureTriangles["overlay-button-customization"]
        for _ in 0..<8 { if customization.isHittable { break }; window.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(customization.exists, "Control bar customization missing")
        // Its observed AX frame includes the label and left form padding.
        // Clicking the label center does not toggle the native disclosure;
        // target the arrow, 26 points from that frame's leading edge.
        customization.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 26, dy: 8)).click()
        XCTAssertTrue(window.descendants(matching: .any)["Add Button"].firstMatch.waitForExistence(timeout: 5), "Control bar customization must expand")
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
                XCTAssertTrue(window.staticTexts["Close Stream Window"].exists, "Shortcut bindings missing")
                XCTAssertFalse(window.staticTexts["Choose and Order Buttons"].exists, "Overlay controls must have their own tab")
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
        // Type-to-select exercises native menu keyboard navigation and avoids
        // coordinates for a menu that AppKit may scroll near the screen edge.
        menu.typeKey("s", modifierFlags: [])
        menu.typeKey("e", modifierFlags: [])
        menu.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.windows["native-settings"].waitForExistence(timeout: 5))
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        XCTAssertTrue(menu.menuItems["Quit Moonlight Native Glass"].waitForExistence(timeout: 5))
        menu.typeKey("q", modifierFlags: [])
        menu.typeKey(.return, modifierFlags: [])
        let quit = NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue)
        expectation(for: quit, evaluatedWith: app)
        waitForExpectations(timeout: 10)
    }

    func testDockReopensLibrary() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--dark"]
        app.launch()
        let window = app.windows["native-library"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(window.exists)
        let dock = XCUIApplication(bundleIdentifier: "com.apple.dock")
        // Dock exposes macOS items by title, rather than their empty label.
        let icon = dock.dockItems["MoonlightNative"]
        XCTAssertTrue(icon.waitForExistence(timeout: 5), "Frontend Dock icon missing")
        // Any coordinate rooted in Dock asks XCTest to activate that system
        // process. Read its icon frame, but synthesize from our app instead.
        let target = icon.frame
        let anchor = app.descendants(matching: .any)["native-status-item"]
        XCTAssertTrue(anchor.waitForExistence(timeout: 5))
        let origin = anchor.frame
        XCTAssertTrue(target.midX.isFinite && target.midY.isFinite && origin.midX.isFinite && origin.midY.isFinite)
        anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: target.midX - origin.midX, dy: target.midY - origin.midY)).click()
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Dock click must reopen the library when no stream window exists")
        app.terminate()
        app.launch()
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Library must appear on a fresh launch after Dock restoration")
        app.terminate()
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
