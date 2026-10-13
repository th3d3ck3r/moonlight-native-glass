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
// Invalidate window callbacks and detach presentation before SDL teardown.
void stopNativeStreamWindow();
void nativeAcknowledgeMenuAction(int action, Uint32 requestID);
void nativePublishMenuState(SDL_Window* window, bool captured, bool statistics, bool muted);

// Present the host-exit confirmation in the process that owns the SDL window.
bool nativeConfirmDisconnectAndExit(SDL_Window* window);
bool nativeStreamDisconnectConfirmationVisible();

// Main-thread connection presentation gate; no SDL window/input until Continue.
void nativeSetConnectionWaiting(bool waiting);
bool nativeConnectionWaiting();

#include <functional>
bool nativeCreateConnectionWindow(const char* host, const char* game, int x, int y, Uint32 flags);
SDL_Window* nativeConnectionWindow();
void nativeResizeAndCenterStreamWindow(SDL_Window* window, int width, int height);
void nativeUpdateConnectionWindow(const char* message, int phase);
void nativeDetachConnectionWindowView();
void nativeEndConnectionWindow();
void nativeSetConnectionCommand(std::function<void(int)> command);
void nativeAttachStreamWindow(SDL_Window* window);

void nativeRestoreConnectionWindow();

void nativeConfirmConnectionQuit(const char* app);
