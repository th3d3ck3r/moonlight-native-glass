"""Compile the production exit shortcut and Session event predicate in the probe."""
from pathlib import Path
source=Path('app/streaming/input/keyboard.cpp').read_text()
a=source.index('    case KeyComboQuitAndExit:')
b=source.index('    case KeyComboToggleKeyboardGrab:',a)
Path('build').mkdir(exist_ok=True)
Path('build/NativeExitShortcutCase.inc').write_text(source[a:b])
source=Path('app/streaming/session.cpp').read_text()
a=source.index('if (event.type == nativeOverlayEventType()')
a=source.index('(',a)+1
end=a; depth=1
while depth:
    depth+=(source[end]=='(')-(source[end]==')')
    end+=1
Path('build/NativeDisconnectEventPredicate.inc').write_text(source[a:end-1])

# Exercise the exact production pre-window gate, not a copied implementation.
a=source.index('    // Hold BEFORE SDL window/fullscreen/input creation.')
a=source.index('    if (m_AsyncConnectionSuccess',a)
b=source.index('\n#endif\n    // If the connection failed',a)
Path('build/NativeConnectionGate.inc').write_text(source[a:b])
