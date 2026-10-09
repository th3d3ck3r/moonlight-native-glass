// CI-only injected diagnostics. Never compiled into or shipped with the app.
#include <csignal>
#include <execinfo.h>
#include <unistd.h>
static void fatalTrace(int signalNumber)
{
    const char label[] = "NATIVE HELPER FATAL BACKTRACE\n";
    write(STDERR_FILENO, label, sizeof(label) - 1);
    void* frames[64];
    const int count = backtrace(frames, 64);
    backtrace_symbols_fd(frames, count, STDERR_FILENO);
    std::signal(signalNumber, SIG_DFL);
    raise(signalNumber);
}
__attribute__((constructor)) static void installTrace()
{
    std::signal(SIGSEGV, fatalTrace);
    std::signal(SIGABRT, fatalTrace);
}
