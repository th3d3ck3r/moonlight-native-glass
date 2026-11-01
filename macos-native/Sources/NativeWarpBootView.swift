import AppKit
import SwiftUI

// MoonlightLG startup: "Smoke accretion".
// Crimson smoke spirals inward and tightens into a spinning accretion disk,
// the cratered moon rises as sunlight sweeps across it, a flash marks the
// disk locking in, and the name fades in. Rendered by SmokeAccretion.metal.
// The type name and API are unchanged so NativeBootPresentation, previews and
// UI tests keep working; one finite coordinator still owns the lifetime and
// rendering stops when it finishes.
struct NativeWarpBootView: View {
    @ObservedObject var presentation: NativeBootPresentation
    var previewTime: Double? = nil
    /// The scene completes slightly before NativeBootPresentation.duration so
    /// the finished frame holds briefly before the fade.
    private static let sceneLength = 3.8

    private func ease(_ value: Double, _ start: Double, _ length: Double) -> Double {
        let p = min(1, max(0, (value - start) / length))
        return p * p * p * (10 + p * (-15 + 6 * p))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 120, paused: previewTime != nil || presentation.phase != .playing)) { timeline in
            let t = previewTime ?? max(0, timeline.date.timeIntervalSince(presentation.startedAt ?? timeline.date))
            let progress = min(1, t / Self.sceneLength)
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let reveal = ease(progress, 0.78, 0.2)
                ZStack {
                    NativeBootView.background
                    SmokeAccretionScene(state: SmokeAccretionState(time: t, bootProgress: progress, isBoot: true))
                        .accessibilityHidden(true)
                    if presentation.logo != nil {
                        // The moon is now the icon; keep the element for accessibility and UI tests.
                        Color.clear
                            .frame(width: side * 0.33, height: side * 0.33)
                            .accessibilityElement()
                            .accessibilityLabel("MoonlightLG icon")
                            .accessibilityAddTraits(.isImage)
                            .accessibilityIdentifier("startup-project-icon")
                    }
                    // Sized so the name sits just below the disk.
                    NativeBootProjectName(diameter: side * 0.46)
                        .blur(radius: 5 * (1 - reveal))
                        .offset(y: 10 * (1 - reveal))
                        .opacity(reveal)
                }
            }
        }
        .ignoresSafeArea()
        .opacity(presentation.phase == .fading ? 0 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MoonlightLG startup animation. Press Escape to skip.")
        .accessibilityIdentifier("native-boot-animation")
        .accessibilityAction(named: Text("Skip startup animation")) { presentation.finish() }
        .onAppear { if previewTime == nil { presentation.start() } }
    }
}
