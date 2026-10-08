import AppKit
import GameController
import SwiftUI

@MainActor final class NativeControllerNavigation: ObservableObject {
    private var tokens: [NSObjectProtocol] = []
    private var owned: [GCController] = []
    private var move: ((MoveCommandDirection) -> Void)?
    private var select: (() -> Void)?
    private var changeComputer: ((Int) -> Void)?
    func start(move: @escaping (MoveCommandDirection) -> Void, select: @escaping () -> Void, changeComputer: @escaping (Int) -> Void) {
        stop()
        self.move = move; self.select = select; self.changeComputer = changeComputer
        tokens = [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.attach() }
            }
        }
        attach()
    }
    private func attach() {
        detach()
        owned = GCController.controllers()
        for controller in owned {
            controller.handlerQueue = .main
            guard let pad = controller.extendedGamepad else { continue }
            for (button, direction) in [(pad.dpad.up, MoveCommandDirection.up), (pad.dpad.down, .down), (pad.dpad.left, .left), (pad.dpad.right, .right)] {
                button.pressedChangedHandler = { [weak self] _, _, pressed in
                    MainActor.assumeIsolated { if pressed && NSApp.isActive { self?.move?(direction) } }
                }
            }
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                MainActor.assumeIsolated { if pressed && NSApp.isActive { self?.select?() } }
            }
            for (button, delta) in [(pad.leftShoulder, -1), (pad.rightShoulder, 1)] {
                button.pressedChangedHandler = { [weak self] _, _, pressed in
                    MainActor.assumeIsolated { if pressed && NSApp.isActive { self?.changeComputer?(delta) } }
                }
            }
        }
    }
    private func detach() {
        for controller in owned {
            guard let pad = controller.extendedGamepad else { continue }
            [pad.dpad.up, pad.dpad.down, pad.dpad.left, pad.dpad.right, pad.buttonA, pad.leftShoulder, pad.rightShoulder].forEach { $0.pressedChangedHandler = nil }
        }
        owned = []
    }
    func stop() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens = []; detach(); move = nil; select = nil; changeComputer = nil
    }
}
