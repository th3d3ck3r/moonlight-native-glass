#pragma once
// Presentation state only. Called from existing engine events, never per frame.
enum class NativeConnectionState { Idle, Connecting, Connected, Poor, Disconnected };
void nativeTitlebarAttach(void* window);
void nativeTitlebarDetach();
void nativeTitlebarSetCapture(bool captured);
void nativeTitlebarSetStatistics(bool visible);
void nativeTitlebarSetConnection(NativeConnectionState state);
void nativeTitlebarConnectionStarted();
void nativeTitlebarControllersChanged();
