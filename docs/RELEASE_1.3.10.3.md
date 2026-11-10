## 🌙 MoonlightLG 1.3.10.3 · Crimson Glass

- 🎮 **Stream responsiveness.** Prioritize the streaming helper and input event loop while a stream is active, with fewer redundant UI updates.
- 🍎 **Optional asynchronous Metal presentation.** On Apple Silicon, choose **Metal** in **Settings → Video**, use hardware decoding and enable **Vertical Sync**. **Asynchronous Metal Presentation** is off by default and takes effect on the next connection. The M1 owner reported a modest improvement in trackpad feel during testing.
- 🖱️ **Mouse diagnostics.** Compare capture behavior and log input and Metal timing from **Settings → Input**.
- 📊 **Touch Bar and hardware monitoring.** Background telemetry sampling and independent stats refreshes reduce work on the stream event thread.
- 🖥️ **Custom host order.** Right-click a computer in the sidebar and choose **Move Up** or **Move Down**. The order persists across restarts.

### 📦 Downloads

Use the Apple Silicon ZIP on **macOS 15 or later**. The assets include complete corresponding source, dependency sources and notices, and SHA-256 checksums.

Stable build **68** was built from `81ff5546ded40b641ed3a581e4a5cd3a6fe69bcd`. [macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42832034198) · [Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42832034270)
