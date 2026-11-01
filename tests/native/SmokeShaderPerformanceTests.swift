import Foundation
import Metal

// Run the exact supplied and optimized stitchable functions at identical inputs.
// Equality exercises the zero-mask culls; measured GPU times remain diagnostic.
@main struct SmokeShaderPerformanceTests {
    static func main() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            preconditionFailure("A real Metal GPU is required for the shader regression")
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        func pipeline(_ name: String) throws -> MTLComputePipelineState {
            let library = try device.makeLibrary(URL: directory.appendingPathComponent(name + ".metallib"))
            guard let function = library.makeFunction(name: "smokeProbe") else {
                preconditionFailure("The test-only dispatch wrapper must compile")
            }
            return try device.makeComputePipelineState(function: function)
        }
        let reference = try pipeline("reference"), optimized = try pipeline("optimized")
        // time, boot progress, boot flag, connected, since connected, progress fill
        let phases: [(String, [Float])] = [
            ("boot-early", [0.6, 0.6 / 3.8, 1, 0, 0, 0]),
            ("boot-arrival", [3.6, 3.6 / 3.8, 1, 0, 0, 0]),
            ("connecting", [3, 1, 0, 0, 0, 0.9]),
            ("connected", [5, 1, 0, 1, 1.5, 1])
        ]
        var report: [[String: Any]] = []
        for strip in [false, true] {
            // Main scene matches the bounded 1,024,000-pixel surface. Touch Bar
            // uses a real 2x 1085x30-point strip (2170x60 physical pixels).
            let width = strip ? 2170 : 1280, height = strip ? 60 : 800
            let count = width * height * 4
            let bytes = count * MemoryLayout<Float>.stride
            let expected = device.makeBuffer(length: bytes, options: .storageModeShared)!
            let actual = device.makeBuffer(length: bytes, options: .storageModeShared)!
            for (name, phase) in phases {
                let parameters: [Float] = [Float(width), Float(height)] + phase + [strip ? 1 : 0, strip ? 2 : 1]
                func run(_ pipeline: MTLComputePipelineState, _ output: MTLBuffer) -> Double {
                    let command = queue.makeCommandBuffer()!
                    let encoder = command.makeComputeCommandEncoder()!
                    encoder.setComputePipelineState(pipeline)
                    encoder.setBuffer(output, offset: 0, index: 0)
                    parameters.withUnsafeBytes { raw in
                        encoder.setBytes(raw.baseAddress!, length: raw.count, index: 1)
                    }
                    let groupWidth = min(16, pipeline.threadExecutionWidth)
                    let groupHeight = min(8, pipeline.maxTotalThreadsPerThreadgroup / groupWidth)
                    encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: groupWidth, height: groupHeight, depth: 1))
                    encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
                    precondition(command.status == .completed && command.error == nil,
                                 "Actual GPU dispatch must complete without an error")
                    return max(0, command.gpuEndTime - command.gpuStartTime) * 1000
                }
                // Interleave paths to avoid making a thermal/warm-up comparison.
                _ = run(reference, expected); _ = run(optimized, actual)
                var oldTimes: [Double] = [], newTimes: [Double] = []
                for _ in 0..<3 {
                    oldTimes.append(run(reference, expected)); newTimes.append(run(optimized, actual))
                }
                let old = expected.contents().bindMemory(to: Float.self, capacity: count)
                let new = actual.contents().bindMemory(to: Float.self, capacity: count)
                var maximumDelta: Float = 0, lit = 0
                for i in stride(from: 0, to: count, by: 4) {
                    for component in 0..<4 {
                        let a = old[i + component], b = new[i + component]
                        precondition(a.isFinite && b.isFinite, "Shader outputs must remain finite")
                        maximumDelta = max(maximumDelta, abs(a - b))
                    }
                    if max(new[i], max(new[i + 1], new[i + 2])) > 0.08 { lit += 1 }
                }
                precondition(maximumDelta <= 1.0 / 255.0,
                             "\(name): optimization must preserve supplied pixels within one 8-bit level; delta=\(maximumDelta)")
                if name != "boot-early" { precondition(lit > 30, "The regression must exercise a lit scene, not two black surfaces") }
                let oldMedian = oldTimes.sorted()[1], newMedian = newTimes.sorted()[1]
                let entry: [String: Any] = ["scene": strip ? "strip-2x" : "main-bounded", "phase": name,
                    "pixels": width * height, "maximumChannelDelta": maximumDelta,
                    "referenceMedianGPUms": oldMedian, "optimizedMedianGPUms": newMedian,
                    "ratio": newMedian > 0 ? oldMedian / newMedian : 0]
                report.append(entry)
                print("GPU \(strip ? "strip-2x" : "main-bounded") \(name): reference \(oldMedian) ms, optimized \(newMedian) ms; max channel delta \(maximumDelta)")
            }
        }
        let data = try JSONSerialization.data(withJSONObject: ["device": device.name, "samples": report], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("results.json"))
        print("PASS: supplied/optimized GPU pixels agree across boot/connection states; GPU times are CI diagnostics, not physical M1 acceptance")
    }
}
