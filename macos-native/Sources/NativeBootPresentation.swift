import AppKit
import AVFoundation
import SwiftUI

// Owned by App, rather than the window's view state: play once per process.
@MainActor final class NativeBootPresentation: ObservableObject {
    enum Phase { case playing, fading, finished }
    @Published private(set) var phase: Phase
    private(set) var player: AVPlayer?
    private var item: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var motionNotification: NSObjectProtocol?
    private var windowNotification: NSObjectProtocol?
    private weak var watchedWindow: NSWindow?
    private var hostingView: NSHostingView<NativeBootView>?
    private var deadline: Task<Void, Never>?
    private var fadeCompletion: Task<Void, Never>?
    private var started = false

    var blocksLibrary: Bool { phase != .finished }

    init(enabled: Bool, resource: URL? = Bundle.main.url(forResource: "boot-animation", withExtension: "mp4"),
         reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
        guard enabled, !reduceMotion, let resource, FileManager.default.fileExists(atPath: resource.path) else {
            phase = .finished
            return
        }
        phase = .playing
        let item = AVPlayerItem(url: resource)
        self.item = item
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player
    }

    func start() {
        guard !started, phase == .playing, let item else { return }
        started = true
        let center = NotificationCenter.default
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            notifications.append(center.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.finish() }
            })
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.item === item, self.phase == .playing else { return }
                if item.status == .readyToPlay { self.player?.play() }
                else if item.status == .failed { self.finish() }
            }
        }
        motionNotification = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self?.finishImmediately() }
            }
        }
        // A corrupt/unavailable media asset must never hold the library hostage.
        deadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
            self?.finish()
        }
    }

    func watchWindow(_ window: NSWindow?) {
        guard phase == .playing, let window, let content = window.contentView else { return }
        if hostingView == nil {
            // NavigationSplitView owns the native window content hierarchy on
            // macOS; a sibling SwiftUI ZStack view is not reliably presented.
            // Attach above that hierarchy, in the same window, without changing
            // its content controller, frame, toolbar or stream routing.
            let host = NSHostingView(rootView: NativeBootView(presentation: self))
            host.frame = content.bounds
            host.autoresizingMask = [.width, .height]
            content.addSubview(host, positioned: .above, relativeTo: nil)
            hostingView = host
        }
        guard window !== watchedWindow else { return }
        if let windowNotification { NotificationCenter.default.removeObserver(windowNotification) }
        watchedWindow = window
        windowNotification = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finishImmediately() }
        }
    }

    func finish() {
        guard phase == .playing else { return }
        stopObservers()
        player?.pause() // Keep the final frame through the crossfade.
        withAnimation(.easeInOut(duration: 0.65)) { phase = .fading }
        fadeCompletion = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 650_000_000) } catch { return }
            self?.finishImmediately()
        }
    }

    func finishImmediately() {
        stopObservers()
        fadeCompletion?.cancel(); fadeCompletion = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil; item = nil
        hostingView?.removeFromSuperview(); hostingView = nil
        phase = .finished
    }

    private func stopObservers() {
        deadline?.cancel(); deadline = nil
        statusObservation?.invalidate(); statusObservation = nil
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        notifications.removeAll()
        if let motionNotification { NSWorkspace.shared.notificationCenter.removeObserver(motionNotification) }
        motionNotification = nil
        if let windowNotification { NotificationCenter.default.removeObserver(windowNotification) }
        windowNotification = nil; watchedWindow = nil
    }

    deinit {
        deadline?.cancel(); fadeCompletion?.cancel()
        statusObservation?.invalidate()
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        if let motionNotification { NSWorkspace.shared.notificationCenter.removeObserver(motionNotification) }
        if let windowNotification { NotificationCenter.default.removeObserver(windowNotification) }
    }
}

private struct NativeBootMovie: NSViewRepresentable {
    let player: AVPlayer?
    final class MovieView: NSView {
        let movieLayer = AVPlayerLayer()
        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            movieLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(movieLayer)
            setAccessibilityElement(false)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layout() {
            super.layout()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            movieLayer.frame = bounds
            CATransaction.commit()
        }
    }
    func makeNSView(context: Context) -> MovieView {
        let view = MovieView(); view.movieLayer.player = player; return view
    }
    func updateNSView(_ view: MovieView, context: Context) { view.movieLayer.player = player }
    static func dismantleNSView(_ view: MovieView, coordinator: ()) { view.movieLayer.player = nil }
}

struct NativeBootView: View {
    @ObservedObject var presentation: NativeBootPresentation
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black
            NativeBootMovie(player: presentation.player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            Button("Skip") { presentation.finish() }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.15))
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityLabel("Skip startup animation")
                .accessibilityIdentifier("native-boot-skip")
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(presentation.phase == .fading ? 0 : 1)
        .onAppear { presentation.start() }
    }
}
