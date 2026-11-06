#pragma once

namespace mlg {
// Called by the recorder worker or replay export, never by stream ingress.
template<class Writing, class Ready, class Wait>
bool waitForWriterReady(unsigned retries, Writing writing, Ready ready, Wait wait) {
    while (writing()) {
        if (ready()) return true;
        if (retries == 0) return false;
        --retries;
        wait();
    }
    return false;
}
}
