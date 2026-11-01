import SwiftUI

/// Inputs for the GPU "Smoke accretion" scene (`SmokeAccretion.metal`).
struct SmokeAccretionState {
    /// Seconds since the scene started.
    var time: Double
    /// 0...1 through the startup sequence (used when `isBoot` is true).
    var bootProgress: Double = 1
    var isBoot = false
    /// 0...1 eased connection state (0 = connecting, 1 = connected).
    var connected: Double = 0
    /// Seconds since the connection completed (drives the shockwave).
    var sinceConnect: Double = 0
    /// 0...1 sweep of the liquid progress ring while connecting.
    var progressFill: Double = 0
    /// Static icon framing.
    var icon = false
}

/// A 3D cratered moon inside a spinning crimson smoke accretion disk.
/// Rendered entirely on the GPU through SwiftUI's `colorEffect` (macOS 14+),
/// shared by the startup animation and the connection screen.
struct SmokeAccretionScene: View {
    var state: SmokeAccretionState

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.black)
                .colorEffect(ShaderLibrary.bundle(.main).smokeAccretion(
                    .float2(Float(geometry.size.width), Float(geometry.size.height)),
                    // Wrapped so float precision stays high in long sessions.
                    .float(Float(state.time.truncatingRemainder(dividingBy: 3600))),
                    .float(Float(state.bootProgress)),
                    .float(state.isBoot ? 1 : 0),
                    .float(Float(state.connected)),
                    .float(Float(state.sinceConnect)),
                    .float(Float(state.progressFill)),
                    .float(state.icon ? 1 : 0)))
        }
    }
}
