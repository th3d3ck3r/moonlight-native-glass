import XCTest

@MainActor final class NativeUIScreensTests: XCTestCase {
    func testCrimsonGlassAppearanceSwitch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--preview-screen=settings-appearance", "--dark"]
        app.launch()
        let window = app.windows["native-settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let toggle = window.descendants(matching: .any)["crimson-glass-toggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        func isEnabled() -> Bool? {
            if let number = toggle.value as? NSNumber { return number.boolValue }
            if let text = toggle.value as? String {
                if text == "1" { return true }; if text == "0" { return false }
            }
            return nil
        }
        if isEnabled() != true { toggle.click() }
        let frame = window.frame
        let crimson = XCTAttachment(screenshot: window.screenshot())
        crimson.name = "crimson-settings-titlebar"; crimson.lifetime = .keepAlways; add(crimson)
        toggle.click()
        XCTAssertEqual(isEnabled(), false)
        let original = XCTAttachment(screenshot: window.screenshot())
        original.name = "original-settings-after-theme-switch"; original.lifetime = .keepAlways; add(original)
        XCTAssertEqual(window.frame, frame, "Appearance switching must not change window geometry")
        toggle.click()
        XCTAssertEqual(isEnabled(), true)
        app.terminate()
        app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(isEnabled(), true, "Crimson preference must persist across launches")
        app.terminate()
    }

    func testNativeStartupArtworkStages() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for (name, time) in [("starfield", 0.12), ("warp", 0.65), ("arrival", 2.3), ("moon-and-satellites", 3.55)] {
            app.launchArguments = ["--design-preview", "--boot-preview", "--boot-frame=\(time)", "--dark"]
            app.launch()
            let window = app.windows["native-library"]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            XCTAssertTrue(window.descendants(matching: .any)["native-boot-animation"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(window.searchFields.firstMatch.exists)
            XCTAssertFalse(window.buttons["Add Computer"].exists)
            if time == 3.55 {
                let name = window.staticTexts["startup-project-name"]
                let icon = window.images["startup-project-icon"]
                XCTAssertTrue(name.waitForExistence(timeout: 5))
                XCTAssertEqual(name.value as? String ?? name.label, "MoonlightLG")
                XCTAssertTrue(icon.exists)
                XCTAssertGreaterThan(name.frame.minY, icon.frame.maxY, "Project name must sit beneath the icon")
                XCTAssertEqual(name.frame.midX, icon.frame.midX, accuracy: 1.5)
            }
            let shot = XCTAttachment(screenshot: window.screenshot())
            shot.name = "native-startup-" + name; shot.lifetime = .keepAlways; add(shot)
            app.terminate()
        }
    }

    func testApolloConnectionFlightOrbitAndContinue() throws {
        for phase in ["flight", "orbit", "error", "reduced"] {
            let app = XCUIApplication()
            app.launchArguments = ["--design-preview", "--preview-screen=connection-" + phase, "--connection-frame=5", "--dark"]
            if phase == "reduced" {
                app.launchArguments = ["--design-preview", "--preview-screen=connection-orbit", "--connection-reduce-motion", "--dark"]
            }
            app.launch()
            let scene = app.descendants(matching: .any)["connection-journey"]
            XCTAssertTrue(scene.waitForExistence(timeout: 10))
            let proceed = app.buttons["connection-continue"]
            if phase == "orbit" || phase == "reduced" {
                XCTAssertTrue(proceed.exists)
                Thread.sleep(forTimeInterval: 2)
                XCTAssertTrue(scene.exists, "Orbit must remain until the user continues")
            } else { XCTAssertFalse(proceed.exists) }
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "apollo-connection-" + phase; capture.lifetime = .keepAlways; add(capture)
            if phase == "orbit" || phase == "reduced" { proceed.click() }
            else { app.buttons["connection-cancel"].click() }
            XCTAssertTrue(app.buttons["Refresh"].waitForExistence(timeout: 5))
            XCTAssertTrue(scene.waitForNonExistence(timeout: 5))
            app.terminate()
        }
    }

    func testBootCompletesInLibraryWindow() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--boot-preview", "--dark"]
        app.launch()
        let window = app.windows["native-library"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let skip = window.descendants(matching: .any)["native-boot-animation"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "Boot playback must appear in the library window")
        // Capture the native expansion and verify startup-only chrome.
        XCTAssertFalse(window.buttons["Add Computer"].exists, "Library must not exist behind startup")
        XCTAssertFalse(window.searchFields.firstMatch.exists, "Startup must have no search toolbar")
        XCTAssertTrue(window.buttons[XCUIIdentifierCloseWindow].exists, "Keep the real window buttons")
        Thread.sleep(forTimeInterval: 0.6)
        let frame = window.frame
        XCTAssertEqual(app.windows.count, 1, "Boot must not create a second window")
        let boot = XCTAttachment(screenshot: window.screenshot())
        boot.name = "boot-in-library-window"; boot.lifetime = .keepAlways; add(boot)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: skip)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(window.exists)
        XCTAssertEqual(window.frame, frame, "Crossfade must retain the same window and size")
        XCTAssertTrue(window.buttons["Add Computer"].isHittable, "Library controls must become available after boot")
        let library = XCTAttachment(screenshot: window.screenshot())
        library.name = "library-after-boot"; library.lifetime = .keepAlways; add(library)
        window.buttons["Add Computer"].click()
        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Library sheet routing must survive the boot container")
        sheet.buttons["Cancel"].click()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet)
        waitForExpectations(timeout: 5)
        app.terminate()
    }

    func testBootSkipReopenAndFreshLaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--boot-preview", "--dark"]
        app.launch()
        let window = app.windows["native-library"]
        let skip = window.descendants(matching: .any)["native-boot-animation"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        app.typeKey(.escape, modifierFlags: [])
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: skip)
        waitForExpectations(timeout: 5)
        window.buttons[XCUIIdentifierCloseWindow].click()
        let item = app.descendants(matching: .any)["native-status-item"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertFalse(skip.exists, "Reopening must not replay the animation")
        app.terminate()
        app.launch()
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "A fresh process should play the animation again")
        app.typeKey(.escape, modifierFlags: [])
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: skip)
        waitForExpectations(timeout: 5)
        app.terminate()
    }

    func testBootFallbacksAndCloseDuringPlayback() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for flag in ["--boot-missing-resource", "--boot-invalid-resource", "--boot-reduce-motion"] {
            app.launchArguments = ["--design-preview", "--boot-preview", flag, "--dark"]
            app.launch()
            let window = app.windows["native-library"]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: window.descendants(matching: .any)["native-boot-animation"].firstMatch)
            waitForExpectations(timeout: 8)
            XCTAssertTrue(window.buttons["Add Computer"].isHittable)
            app.terminate()
        }
        // Hold a genuine startup frame so accessibility/launch timing cannot
        // turn this into a close-after-completion test. Natural completion is
        // exercised separately in testBootCompletesInLibraryWindow.
        app.launchArguments = ["--design-preview", "--boot-preview", "--boot-frame=1.85", "--dark"]
        app.launch()
        let window = app.windows["native-library"]
        XCTAssertTrue(window.descendants(matching: .any)["native-boot-animation"].firstMatch.waitForExistence(timeout: 10))
        window.buttons[XCUIIdentifierCloseWindow].click()
        let item = app.descendants(matching: .any)["native-status-item"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertFalse(window.descendants(matching: .any)["native-boot-animation"].firstMatch.exists, "Closing during boot must stop playback and restore directly to the library")
        app.terminate()
    }

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
        let graphs = window.descendants(matching: .any)["stream-statistics-graphs"].firstMatch
        XCTAssertTrue(graphs.exists, "Stream graphs setting missing")
        graphs.click(); graphs.click()
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

    func testMoonlightLGAboutVersion() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--design-preview", "--preview-screen=about", "--dark"]
        app.launch()
        let about = app.descendants(matching: .any)["native-about"].firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 10))
        XCTAssertTrue(about.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", "MoonlightLG", "MoonlightLG")).firstMatch.exists)
        XCTAssertTrue(about.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "1.3.1.1U", "1.3.1.1U")).firstMatch.exists)
        XCTAssertTrue(about.textViews.matching(NSPredicate(format: "value CONTAINS %@", "Moonlight Qt 6.2.0")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: about.screenshot())
        shot.name = "moonlightlg-about-version"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    func testNativeScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "preview-settings", withExtension: "json"))
        let screens = ["main-light", "main-dark", "main-compact", "empty", "loading", "offline", "unpaired", "add", "pair", "details", "settings-video", "settings-audio", "settings-recording", "settings-input", "settings-network", "settings-advanced", "settings-shortcuts"]
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
            if screen == "settings-recording" {
                XCTAssertTrue(window.descendants(matching: .any)["recording-enabled"].firstMatch.exists, "Recording opt-in missing")
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
        let menu = app.menus.containing(.menuItem, identifier: "Open Library").firstMatch
        XCTAssertTrue(menu.menuItems["Open Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(menu.menuItems["Settings…"].exists)
        XCTAssertFalse(menu.menuItems["Restore Stream Window"].isEnabled)
        XCTAssertFalse(menu.menuItems["Capture Input"].isEnabled)
        XCTAssertFalse(menu.menuItems["Disconnect"].isEnabled)
        XCTAssertTrue(menu.menuItems["Open Engine Logs"].exists)
        XCTAssertTrue(menu.menuItems["About MoonlightLG"].exists)
        XCTAssertTrue(menu.menuItems["Quit MoonlightLG"].exists)
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
        XCTAssertTrue(menu.menuItems["Quit MoonlightLG"].waitForExistence(timeout: 5))
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
        let icon = dock.dockItems["MoonlightLG"]
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

