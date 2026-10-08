import AppKit
import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: EngineStore
    @Environment(\.openSettings) private var openSettings
    @State private var previewConfigured = false
    @State private var search = ""
    @State private var showHidden = false
    @State private var addPresented = false
    @State private var details: Computer?
    @State private var removal: Computer?
    @State private var quitApp: Computer?
    @State private var rename: Computer?
    @FocusState private var focusedGame: Int?
    @StateObject private var controller = NativeControllerNavigation()
    @State private var columnCount = 4

    private var games: [Game] {
        (store.selected?.apps ?? []).filter { (showHidden || !$0.hidden || $0.id == store.selected?.runningApp) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }
    private var controlsEnabled: Bool { store.ready && !store.streamActive && store.pairing == nil && !store.addingHost && !store.testingConnection }

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedID) {
                Section("Computers") {
                    ForEach(store.computers) { computer in
                        ComputerRow(computer: computer).tag(computer.id)
                            .contextMenu { computerActions(computer) }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 340)
            .navigationTitle("Computers")
        } detail: {
            VStack(spacing: 0) {
                if store.preview {
                    Label("Design preview · Sample content", systemImage: "photo")
                        .font(.callout).foregroundStyle(.secondary).padding(10)
                }
                if let computer = store.selected { library(computer) }
                else { computersOverview }
                statusBar
            }
            .navigationTitle(store.selected?.name ?? "Moonlight Native Glass")
            .searchable(text: $search, prompt: "Search games")
            .toolbar {
                ToolbarItemGroup {
                    Button { addPresented = true } label: { Label("Add Computer", systemImage: "plus") }
                        .help("Add a computer by hostname or IP address").disabled(!controlsEnabled)
                    Button { store.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .help("Refresh computers").disabled(store.streamActive)
                    if let computer = store.selected {
                        Button { details = computer } label: { Label("Computer Details", systemImage: "info.circle") }
                            .help("Show computer details")
                    }
                    Menu {
                        Toggle("Show Hidden Games", isOn: $showHidden)
                    } label: { Label("Library Options", systemImage: "line.3.horizontal.decrease.circle") }
                    .help("Game library options")
                    SettingsLink { Label("Settings", systemImage: "gearshape") }.help("Streaming settings")
                }
            }
        }
        .sheet(isPresented: $addPresented) { AddComputerSheet(store: store) }
        .sheet(item: $store.pairing) { request in PairingSheet(request: request).interactiveDismissDisabled() }
        .sheet(item: $details) { ComputerDetailsSheet(computer: $0) }
        .sheet(item: $rename) { RenameComputerSheet(store: store, computer: $0) }
        .background(NativeWindowAccessor { store.libraryWindow = $0; $0?.identifier = NSUserInterfaceItemIdentifier("native-library"); $0?.setAccessibilityIdentifier("native-library")
            if store.preview { let compact = CommandLine.arguments.contains("--compact"); $0?.setContentSize(NSSize(width: compact ? 680 : 1080, height: compact ? 460 : 720)) } }.frame(width: 0, height: 0))
        .alert(item: Binding(get: { store.message?.settingsScene == false ? store.message : nil }, set: { store.message = $0 })) { message in Alert(title: Text(message.title), message: Text(message.detail), dismissButton: .default(Text("OK"))) }
        .confirmationDialog("Remove \(removal?.name ?? "computer")?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            if let computer = removal { Button("Remove Computer", role: .destructive) { store.send("remove", ["host": computer.id]) } }
        } message: { Text("This removes the saved computer and pairing from this app.") }
        .confirmationDialog("Quit the running app?", isPresented: Binding(get: { quitApp != nil }, set: { if !$0 { quitApp = nil } }), titleVisibility: .visible) {
            if let computer = quitApp { Button("Quit App", role: .destructive) { store.send("quitApp", ["host": computer.id]) } }
        } message: { Text("Unsaved progress on the host may be lost.") }
        .confirmationDialog("Quit \(store.quitRequired ?? "the running app")?", isPresented: Binding(get: { store.quitRequired != nil }, set: { if !$0 { store.quitRequired = nil } }), titleVisibility: .visible) {
            Button("Quit and Start Selected Game", role: .destructive) { store.confirmQuit() }
            Button("Cancel", role: .cancel) { store.cancelLaunch() }
        } message: { Text("Unsaved progress in the running app may be lost.") }
        .onReceive(NotificationCenter.default.publisher(for: .nativeAddComputer)) { _ in if controlsEnabled { addPresented = true } }
        .onAppear {
            configureController()
            guard store.preview, !previewConfigured else { return }
            previewConfigured = true
            let args = CommandLine.arguments
            guard let screen = nativeArgument("--preview-screen") else { return }
            if screen.hasPrefix("settings-") { openSettings() }
            else if screen == "add" { addPresented = true }
            else if screen == "details" { details = store.selected }
            else if screen == "pair", let computer = store.selected { store.pairing = PairingRequest(computer: computer, pin: "1234") }
        }
        .onDisappear { controller.stop() }
        .onChange(of: store.streamActive) { _, active in if active { controller.stop() } else { configureController() } }
        .onChange(of: store.selectedID) { _, _ in focusedGame = nil; search = "" }
    }

    private func library(_ computer: Computer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer").font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(computer.name).font(.title2).fontWeight(.semibold).lineLimit(1)
                    Label(computer.status, systemImage: computer.online ? "checkmark.circle" : "network.slash")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if computer.online && !computer.unknown && !computer.paired {
                    NativePrimaryButton(title: "Pair Computer", symbol: "link") { store.pair(computer) }.disabled(!controlsEnabled)
                } else if !computer.online && !computer.unknown {
                    Button("Wake Computer") { store.send("wake", ["host": computer.id]) }.disabled(!controlsEnabled)
                }
            }.padding(24)
            if computer.unknown {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Checking Connection…").font(.headline)
                    Text("Contacting your computer's streaming service.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !computer.online {
                empty("Computer Offline", "Start the host's streaming service and check Local Network permission in System Settings.", symbol: "network.slash")
            } else if !computer.paired {
                empty("Pair Your Computer", "Pair with Sunshine or a compatible host to see your games and apps.", symbol: "link")
            } else if !computer.supported {
                empty("Host Version Not Supported", "Update the streaming service on your computer, then refresh its connection.", symbol: "exclamationmark.triangle")
            } else if games.isEmpty {
                empty(search.isEmpty ? "No Games Yet" : "No Matching Games", search.isEmpty ? "Your host's app list will appear here when available. Use Refresh to check again." : "Try a different search.", symbol: "gamecontroller")
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 215), spacing: 20)], spacing: 24) {
                            ForEach(games) { game in
                                Button { store.startStream(computer, game: game) } label: {
                                    GameCard(game: game, running: computer.runningApp == game.id)
                                        .padding(4)
                                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(focusedGame == game.id ? Color.accentColor : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .focused($focusedGame, equals: game.id)
                                .onMoveCommand { moveGames($0) }
                                .help("Stream \(game.name)")
                                .onAppear { store.requestArtwork(computer, game: game) }
                                .disabled(!controlsEnabled || !computer.supported)
                                .contextMenu {
                                    Button("Stream \(game.name)") { store.startStream(computer, game: game) }.disabled(!controlsEnabled)
                                    Button(game.hidden ? "Show Game" : "Hide Game") {
                                        store.send("hideGame", ["host": computer.id, "app": game.id, "hidden": !game.hidden])
                                    }.disabled(!controlsEnabled)
                                    if computer.runningApp == game.id { Button("Quit App…", role: .destructive) { quitApp = computer }.disabled(!controlsEnabled) }
                                }
                            }
                        }.padding(.horizontal, 24).padding(.bottom, 24)
                    }
                    .onAppear { columnCount = max(1, Int((geometry.size.width - 28) / 170)) }
                    .onChange(of: geometry.size.width) { _, width in columnCount = max(1, Int((width - 28) / 170)) }
                }
            }
        }
    }

    private var computersOverview: some View {
        Group {
            if store.computers.isEmpty {
                VStack(spacing: 18) {
                    empty("Your Computers", "Computers running Sunshine or a compatible streaming host appear here. You can also add one by address.", symbol: "desktopcomputer")
                    Button("Add Computer…") { addPresented = true }.disabled(!controlsEnabled).padding(.bottom, 32)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 20) {
                        ForEach(store.computers) { computer in
                            Button { store.selectedID = computer.id } label: {
                                VStack(spacing: 14) {
                                    Image(systemName: "desktopcomputer").font(.system(size: 48)).foregroundStyle(.secondary)
                                    Text(computer.name).font(.headline)
                                    Text(computer.status).font(.callout).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity).padding(28)
                                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }.padding(24)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func empty(_ title: String, _ description: String, symbol: String) -> some View {
        ContentUnavailableView { Label(title, systemImage: symbol) } description: { Text(description).frame(maxWidth: 430) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider()
            HStack(spacing: 8) {
                if !store.ready || (store.streamActive && !store.streamStarted) { ProgressView().controlSize(.small) }
                Text(store.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                if store.streamActive && !store.streamStarted { Button("Cancel") { store.cancelLaunch() }.controlSize(.small) }
            }.padding(.horizontal, 16).padding(.bottom, 9)
            if store.streamStarted {
                Text("Hide the stream window with Close Stream Window (see Settings → Shortcuts). Disconnect with Disconnect and Exit or Start + Select + L1 + R1 on your controller.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 9)
            }
            if !store.warnings.isEmpty {
                Label(store.warnings.joined(separator: "\n"), systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 9)
            }
        }
    }
    @ViewBuilder private func computerActions(_ computer: Computer) -> some View {
        Button("Computer Details…") { details = computer }
        Button("Rename…") { rename = computer }.disabled(!controlsEnabled)
        if computer.online && !computer.paired { Button("Pair Computer…") { store.pair(computer) }.disabled(!controlsEnabled) }
        Button("Wake Computer") { store.send("wake", ["host": computer.id]) }.disabled(!controlsEnabled)
        if computer.runningApp != 0 { Button("Quit Running App…", role: .destructive) { quitApp = computer }.disabled(!controlsEnabled) }
        Divider()
        Button("Remove Computer…", role: .destructive) { removal = computer }.disabled(!controlsEnabled)
    }
    private func moveGames(_ direction: MoveCommandDirection) {
        guard !games.isEmpty else { return }
        let index = games.firstIndex { $0.id == focusedGame } ?? 0
        let delta: Int
        switch direction { case .left: delta = -1; case .right: delta = 1; case .up: delta = -columnCount; case .down: delta = columnCount; default: delta = 0 }
        focusedGame = games[min(max(0, index + delta), games.count - 1)].id
    }
    private func configureController() {
        guard !store.streamActive else { return }
        controller.start(move: { direction in if store.libraryWindow?.isKeyWindow == true { moveGames(direction) } }, select: {
            guard controlsEnabled, store.libraryWindow?.isKeyWindow == true, let computer = store.selected else { return }
            if !computer.paired && computer.online { store.pair(computer) }
            else if let game = games.first(where: { $0.id == focusedGame }) ?? games.first { store.startStream(computer, game: game) }
        }, changeComputer: { delta in
            guard store.libraryWindow?.isKeyWindow == true, !store.computers.isEmpty else { return }
            let index = store.computers.firstIndex { $0.id == store.selectedID } ?? 0
            store.selectedID = store.computers[min(max(0, index + delta), store.computers.count - 1)].id
        })
    }
}

struct ComputerRow: View {
    let computer: Computer
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "desktopcomputer").foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(computer.name).lineLimit(1)
                Text(computer.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Circle().fill(computer.online ? Color.green : Color.secondary).frame(width: 6, height: 6).accessibilityHidden(true)
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

struct NativePrimaryButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if #available(macOS 26, *), !reduceTransparency {
            Button(action: action) { Label(title, systemImage: symbol) }.buttonStyle(.glassProminent)
        } else {
            Button(action: action) { Label(title, systemImage: symbol) }.buttonStyle(.borderedProminent)
        }
    }
}

struct GameCard: View {
    let game: Game
    let running: Bool
    @State private var artwork: NSImage?
    @State private var hover = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor))
                if let artwork { Image(nsImage: artwork).resizable().scaledToFill().clipped() }
                else { Image(systemName: game.name == "Desktop" ? "desktopcomputer" : "gamecontroller").font(.system(size: 38)).foregroundStyle(.secondary) }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(hover ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: hover ? 2 : 0.5))
            Text(game.name).font(.headline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if running { Label("Running", systemImage: "play.fill").font(.caption).foregroundStyle(.secondary) }
            else if game.hidden { Label("Hidden", systemImage: "eye.slash").font(.caption).foregroundStyle(.secondary) }
            else if game.hdr { Text("HDR supported").font(.caption).foregroundStyle(.secondary) }
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .accessibilityElement(children: .combine)
        .task(id: game.artwork) {
            artwork = nil
            guard let url = URL(string: game.artwork), url.isFileURL else { return }
            let data = await Task.detached(priority: .utility) { try? Data(contentsOf: url, options: .mappedIfSafe) }.value
            guard !Task.isCancelled, let data else { return }
            artwork = NSImage(data: data)
        }
    }
}
