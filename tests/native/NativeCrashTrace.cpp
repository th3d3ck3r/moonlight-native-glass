// CI-only injected diagnostics. Never compiled into or shipped with the app.
#include <csignal>
#include <execinfo.h>
#include <mach-o/dyld.h>
#include <cstring>
#include <unistd.h>
static void fatalTrace(int signalNumber)
{
    const char label[] = "NATIVE HELPER FATAL BACKTRACE\n";
    write(STDERR_FILENO, label, sizeof(label) - 1);
    void* frames[64];
    const int count = backtrace(frames, 64);
    backtrace_symbols_fd(frames, count, STDERR_FILENO);
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* name = _dyld_get_image_name(i);
        if (name && (strstr(name, "crypto") || strstr(name, "ssl") || strstr(name, "QtNetwork"))) {
            write(STDERR_FILENO, name, strlen(name));
            write(STDERR_FILENO, "\n", 1);
        }
    }
    std::signal(signalNumber, SIG_DFL);
    raise(signalNumber);
}
__attribute__((constructor)) static void installTrace()
{
    std::signal(SIGSEGV, fatalTrace);
    std::signal(SIGABRT, fatalTrace);
}
