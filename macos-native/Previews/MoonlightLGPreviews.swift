import AppKit
import SwiftUI

// Open this file with the "MoonlightLG UI Preview" scheme selected, then enable
// Editor > Canvas. These previews use sample data and never launch the engine.
@MainActor private struct MoonlightLGStartupPreview: View {
    @State private var replay = UUID()
    var body: some View {
        VStack(spacing: 12) {
            MoonlightLGStartupPreviewCycle().id(replay)
                .frame(width: 960, height: 640)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Replay Startup") { replay = UUID() }
        }
        .padding(16)
    }
}

@MainActor private struct MoonlightLGStartupPreviewCycle: View {
    @StateObject private var boot = NativeBootPresentation(enabled: true, reduceMotion: false)
    @StateObject private var store = EngineStore(preview: true)
    var body: some View {
        ZStack(alignment: .topLeading) {
            NativeBootView.background
            if boot.blocksLibrary {
                NativeWarpBootView(presentation: boot)
                // Canvas has no native NSWindow chrome. Represent the three
                // buttons visually; the running app uses real AppKit buttons.
                HStack(spacing: 8) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { color in
                        Circle().fill(color).frame(width: 12, height: 12)
                    }
                }.padding(16).accessibilityHidden(true)
            } else {
                LibraryView(store: store, sizesPreviewWindow: false).transition(.opacity)
            }
        }
        .crimsonGlassTheme()
        .animation(.easeInOut(duration: 0.4), value: boot.phase)
        .onDisappear { boot.finishImmediately() }
    }
}

@MainActor private struct MoonlightLGLibraryPreview: View {
    @StateObject private var store = EngineStore(preview: true)
    var body: some View { LibraryView(store: store, sizesPreviewWindow: false).frame(width: 1080, height: 720) }
}

#Preview("MoonlightLG · Live startup") {
    MoonlightLGStartupPreview().preferredColorScheme(.dark)
}

#Preview("MoonlightLG · Library · Dark") {
    MoonlightLGLibraryPreview().preferredColorScheme(.dark)
}

#Preview("MoonlightLG · Library · Light") {
    MoonlightLGLibraryPreview().preferredColorScheme(.light)
}

@MainActor private struct MoonlightLGArtworkPreview: View {
    @StateObject private var boot = NativeBootPresentation(enabled: true, reduceMotion: false)
    let time: Double
    var body: some View {
        NativeBootView(presentation: boot, previewTime: time).frame(width: 960, height: 640)
    }
}

#Preview("MoonlightLG · Construction rings") {
    MoonlightLGArtworkPreview(time: 2.3)
}

#Preview("MoonlightLG · Existing logo") {
    MoonlightLGArtworkPreview(time: 3.55)
}

@MainActor private struct NativeCrimsonWarpFramePreview: View {
    @StateObject private var boot = NativeBootPresentation(enabled: true, reduceMotion: false)
    var body: some View {
        NativeWarpBootView(presentation: boot, previewTime: 3.3)
            .frame(width: 960, height: 640).crimsonGlassTheme()
    }
}
#Preview("MoonlightLG · Crimson Warp arrival frame") { NativeCrimsonWarpFramePreview() }


#Preview("Apollo Connection · Flight") {
    LibraryView(store: apolloPreview(orbit: false), sizesPreviewWindow: false)
        .frame(width: 960, height: 640).crimsonGlassTheme()
}
#Preview("Apollo Connection · Orbit") {
    LibraryView(store: apolloPreview(orbit: true), sizesPreviewWindow: false)
        .frame(width: 960, height: 640).crimsonGlassTheme()
}
@MainActor private func apolloPreview(orbit: Bool) -> EngineStore {
    let store = EngineStore(preview: true)
    if let host = store.computers.first, let game = host.apps.first {
        var journey = ConnectionJourney(computer: host, game: game)
        journey.detail = orbit ? "Connected · Awaiting Continue" : "Starting video stream…"
        if orbit { journey.phase = .connected; journey.connectedAt = Date().addingTimeInterval(-3) }
        store.connectionJourney = journey
    }
    return store
}
