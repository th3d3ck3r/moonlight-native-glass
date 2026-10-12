# MoonlightLG 1.1.02U — connection controls

The owner reported that clicking Continue left the Apollo orbit unchanged.
Connection controls now use AppKit NSButton target/action dispatch inside the
Qt/SDL-owned NSHostingView, with first-click acceptance. The Canvas animation,
connection protocol and same SDL window handoff remain intact.

The regression fixture now runs QGuiApplication alongside SDL and the production
Swift host dylib. It sends actual down/up events to native Cancel and Continue,
checks hit testing and callback delivery, verifies the Continue gate is released,
and retains the same window/content identity for stream controls. It uses a Metal
window, checks restore, host-game sheets and Close, then tears down normally.

Validation pending. No live host is available on the macOS CI runner; actual
host/decoder handoff requires the owner's Mac acceptance test. U package links
are shared directly with the owner, never posted as releases or downloads here.
