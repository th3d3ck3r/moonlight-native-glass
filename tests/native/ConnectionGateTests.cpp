#include <cassert>
#include <cstdio>
#include <vector>
// Test doubles record the gate's calls; the decision code is extracted directly
// from Session::exec. Full builds compile it against actual Qt/SDL as well.
enum { SDL_GETEVENT, SDL_QUIT, SDL_KEYDOWN, SDL_MOUSEWHEEL,
       SDL_CONTROLLERAXISMOTION, SDL_CONTROLLERBUTTONUP, SDL_FINGERDOWN, SDL_FINGERMOTION };
struct SDL_Event {};
static bool waiting = true, quitQueued = false;
static int polls = 0, flushes = 0;
bool nativeConnectionWaiting() { return waiting; }
int SDL_PeepEvents(SDL_Event*, int, int, int, int) { bool q = quitQueued; quitQueued = false; return q; }
void SDL_FlushEvents(int, int) { ++flushes; }
struct Flag { bool value; bool toBool() const { return value; } };
struct QTimer { template<class T> static void singleShot(int ms, T*, void(T::*)()) { assert(ms == 50); ++polls; } };
struct Preferences { bool quitAppAfter = true; };
struct Session {
    bool m_AsyncConnectionSuccess = true, m_ShouldExit = false, m_AudioMuted = true, gate = true;
    bool opened = false, cleaned = false;
    Preferences prefs;
    Preferences* m_Preferences = &prefs;
    Flag property(const char*) { return {gate}; }
    void setProperty(const char*, bool value) { gate = value; }
    void exec() {
#include "NativeConnectionGate.inc"
        if (!m_AsyncConnectionSuccess) { cleaned = true; return; }
        opened = true;
    }
};
int main() {
    Session session;
    for (int i = 0; i < 100; ++i) session.exec();
    assert(!session.opened && !session.cleaned && session.m_AudioMuted && polls == 100 && flushes == 0);
    waiting = false; session.exec();
    assert(session.opened && !session.gate && !session.m_AudioMuted && flushes == 3);
    Session cancelled; waiting = true; quitQueued = true; cancelled.exec();
    assert(cancelled.cleaned && !cancelled.opened && !cancelled.prefs.quitAppAfter);
    Session lost; lost.m_ShouldExit = true; lost.exec();
    assert(lost.cleaned && !lost.opened);
    Session stock; stock.gate = false; stock.m_AudioMuted = false; stock.exec();
    assert(stock.opened && !stock.cleaned && !stock.m_AudioMuted);
    puts("PASS: production connection gate holds audio/window/input, enters only on Continue, cleans up Cancel/loss, preserves ordinary Qt");
}
