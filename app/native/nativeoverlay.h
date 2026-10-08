#pragma once
#include <SDL.h>
// Native presentation only. No video-layer or timing ownership.
bool nativeOverlayPresent(int type, bool enabled, const char* text);
void nativeOverlayAttach(void* window, const char* token);
void nativeOverlayDetach();
Uint32 nativeOverlayEventType();
void nativeOverlaySetControlsVisible(bool visible);
bool nativeOverlayConfigured();
int nativeOverlayShortcut(const SDL_KeyboardEvent* event);
bool nativeOverlayControlsEnabled();
bool nativeOverlayConsumeKeyRelease(bool& consumed, Uint8 state);

// Queue an existing action on SDL's main event loop; never call input from AppKit.
void nativeOverlayPerformAction(int action);
