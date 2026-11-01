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

/// Bound the expensive procedural effect's physical pixels on Retina displays.
/// Layout, text and controls remain at the native backing resolution.
/// Keep the reference's aspect ratio and wall-clock timing at every size.
enum SmokeAccretionRenderBudget {
    static let maximumPixels = CGSize(width: 1280, height: 800)
    static func factor(size: CGSize, displayScale: CGFloat) -> CGFloat {
        max(1, max(size.width * displayScale / maximumPixels.width,
                   size.height * displayScale / maximumPixels.height))
    }
}

/// A 3D cratered moon inside a spinning crimson smoke accretion disk.
/// Rendered entirely on the GPU through SwiftUI's `colorEffect` (macOS 14+),
/// shared by the startup animation and the connection screen.
struct SmokeAccretionScene: View {
    var state: SmokeAccretionState
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let factor = state.isBoot ? SmokeAccretionRenderBudget.factor(size: geometry.size, displayScale: displayScale) : 1
            if factor > 1 {
                let size = CGSize(width: geometry.size.width / factor, height: geometry.size.height / factor)
                scene(size: size)
                    .frame(width: size.width, height: size.height)
                    // Rasterize before scaling, so a large 2x window does not
                    // multiply this procedural shader's cost by four.
                    .drawingGroup(opaque: true, colorMode: .nonLinear)
                    .scaleEffect(factor)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                scene(size: geometry.size)
            }
        }
        .clipped()
    }

    private func scene(size: CGSize) -> some View {
        Rectangle()
            .fill(Color.black)
            .colorEffect(ShaderLibrary.bundle(.main).smokeAccretion(
                .float2(Float(size.width), Float(size.height)),
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
