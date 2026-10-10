#pragma once
#include <SDL.h>
// Hide the existing native stream window without ending its session.
bool nativeHideStreamWindow(SDL_Window* window);
// Session supplies its existing safe fullscreen transition; no renderer logic
// is duplicated in the native window adapter. Clear before window destruction.
void nativeSetStreamFullscreenTransition(bool (*transition)(SDL_Window*, Uint32));
bool nativeStreamWindowHasHiddenFullscreen(SDL_Window* window);
Uint32 nativeRestoreStreamWindowEventType();
void nativeRestoreStreamWindow(Uint32 windowID);
// Take over the helper pipe while Session deliberately suspends Qt processing.
bool nativeStartStreamMenuCommands(int fd = 0);
bool nativeStreamMenuCommandsEnabled();
void nativeStopStreamMenuCommands();
void nativeAcknowledgeMenuAction(int action, Uint32 requestID);
void nativePublishMenuState(SDL_Window* window, bool captured, bool statistics, bool muted);
