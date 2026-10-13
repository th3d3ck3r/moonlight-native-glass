#pragma once
// Presentation state only. Called from existing engine events, never per frame.
enum class NativeConnectionState { Idle, Connecting, Connected, Poor, Disconnected };
void nativeTitlebarAttach(void* window);
void nativeTitlebarDetach();
void nativeTitlebarSetWindowTransition(bool transitioning);
void nativeTitlebarSetCapture(bool captured);
void nativeTitlebarSetStatistics(bool visible);
void nativeTitlebarSetConnection(NativeConnectionState state);
void nativeTitlebarConnectionStarted();
void nativeTitlebarControllersChanged();

#include <stdint.h>
void nativeTitlebarSetRecording(bool available, bool recording, bool buffering, bool ready, bool saving, bool failed, uint64_t seconds, const char* message);
