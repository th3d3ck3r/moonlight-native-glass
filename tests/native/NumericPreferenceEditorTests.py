"""Exercise the actual AppKit numeric editor delegate, before Return/focus loss."""
from pathlib import Path
import subprocess
import tempfile

source = Path('macos-native/Sources/NativeSettingsView.swift').read_text()
start = source.index('struct NativeIntegerPreferenceEditor: NSViewRepresentable {')
end = source.index('\nprivate struct OverlaySettings: View', start)
editor = 'import AppKit\nimport SwiftUI\n' + source[start:end]
tests = r'''
import AppKit
import Foundation
@main struct NumericPreferenceEditorTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        var writes: [Int] = []
        let editor = NativeIntegerPreferenceEditor(value: 20000, bounds: 500...150000,
            label: "Bitrate (Kbps)", identifier: "setting-bitrateKbps") { writes.append($0) }
        let delegate = NativeIntegerPreferenceEditor.Coordinator(editor)
        let field = NSTextField(string: "64000")
        delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(writes == [64000], "Valid bandwidth must be submitted while editing, without Return or focus loss")
        delegate.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        precondition(writes == [64000], "Ending the same edit must not duplicate its write")
        for draft in ["", "64x", "-1", "499", "150001", "64000.5"] {
            field.stringValue = draft
            delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
            precondition(writes == [64000], "Incomplete or invalid text must not overwrite saved bandwidth")
        }
        delegate.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        precondition(field.stringValue == "64000", "Invalid final draft must recover the last submitted value")
        field.stringValue = "128000"
        delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(writes == [64000, 128000], "Bitrate units are Kbps; do not scale a typed value")
        delegate.bounds = 500...500000
        field.stringValue = "240000"
        delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(writes.last == 240000, "Unlocked bitrate range remains available")
        print("PASS: numeric preference autosave before blur, invalid draft protection, Kbps units and unlocked range")
    }
}
'''
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    (root / 'Editor.swift').write_text(editor)
    (root / 'Tests.swift').write_text(tests)
    executable = root / 'numeric-preference-tests'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
                    str(root / 'Editor.swift'), str(root / 'Tests.swift'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
