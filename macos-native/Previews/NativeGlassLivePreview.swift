import AppKit
import SwiftUI

// Open this file with the "Moonlight UI Preview" scheme selected, then enable
// Editor > Canvas. These previews use sample data and never launch the engine.
@MainActor private struct NativeGlassStartupPreview: View {
    @State private var replay = UUID()
    var body: some View {
        VStack(spacing: 12) {
            NativeGlassStartupPreviewCycle().id(replay)
                .frame(width: 960, height: 640)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("Replay Startup") { replay = UUID() }
        }
        .padding(16)
    }
}

@MainActor private struct NativeGlassStartupPreviewCycle: View {
    @StateObject private var boot = NativeBootPresentation(enabled: true, reduceMotion: false)
    @StateObject private var store = EngineStore(preview: true)
    var body: some View {
        ZStack(alignment: .topLeading) {
            NativeBootView.background
            if boot.blocksLibrary {
                NativeBootView(presentation: boot)
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
        .animation(.easeInOut(duration: 0.4), value: boot.phase)
        .onDisappear { boot.finishImmediately() }
    }
}

@MainActor private struct NativeGlassLibraryPreview: View {
    @StateObject private var store = EngineStore(preview: true)
    var body: some View { LibraryView(store: store, sizesPreviewWindow: false).frame(width: 1080, height: 720) }
}

#Preview("Native Glass · Live startup") {
    NativeGlassStartupPreview().preferredColorScheme(.dark)
}

#Preview("Native Glass · Library · Dark") {
    NativeGlassLibraryPreview().preferredColorScheme(.dark)
}

#Preview("Native Glass · Library · Light") {
    NativeGlassLibraryPreview().preferredColorScheme(.light)
}

@MainActor private struct NativeGlassArtworkPreview: View {
    @StateObject private var boot = NativeBootPresentation(enabled: true, reduceMotion: false)
    let time: Double
    var body: some View {
        NativeBootView(presentation: boot, previewTime: time).frame(width: 960, height: 640)
    }
}

#Preview("Native Glass · Construction rings") {
    NativeGlassArtworkPreview(time: 1.85)
}

#Preview("Native Glass · Existing logo") {
    NativeGlassArtworkPreview(time: 3.55)
}
