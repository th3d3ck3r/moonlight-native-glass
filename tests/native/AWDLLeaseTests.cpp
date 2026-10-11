#include "../../macos-native/AWDLHelper/AWDLLeaseCore.h"
#include <cassert>
#include <iostream>
#include <vector>

struct Interface {
    bool up = true, present = true, marker = false;
    bool setFails = false, journalFails = false;
    int reads = 0;
    std::vector<std::string> events;
    AWDLLeaseCore core(bool recovery = false) {
        return AWDLLeaseCore([this]() -> std::optional<bool> {
            reads++; return present ? std::optional<bool>(up) : std::nullopt;
        }, [this](bool value) {
            events.push_back(value ? "up" : "down");
            if (setFails) return false;
            up = value; return true;
        }, [this](bool value) {
            events.push_back(value ? "journal" : "clear");
            if (journalFails) return false;
            marker = value; return true;
        }, recovery);
    }
};
int main() {
    { // Idle/default-off does absolutely no interface work.
        Interface device; auto core = device.core(); core.tick(100);
        assert(device.reads == 0 && device.events.empty());
    }
    { // Journal first; preserve suppression until the last client's lease ends.
        Interface device; auto core = device.core();
        assert(core.renew(1, 0)); assert(!device.up && device.marker);
        assert((device.events == std::vector<std::string>{"journal", "down"}));
        assert(core.renew(2, 2)); assert(core.release(1)); assert(!device.up);
        assert(core.release(2)); assert(device.up && !device.marker);
    }
    { // A hung/killed frontend cannot leave AWDL disabled indefinitely.
        Interface device; auto core = device.core(); assert(core.renew(1, 0));
        core.tick(14); assert(!device.up);
        assert(core.renew(1, 14)); core.tick(28); assert(!device.up);
        core.tick(29); assert(device.up && !device.marker);
    }
    { // macOS bringing AWDL up gets corrected while a lease is live.
        Interface device; auto core = device.core(); assert(core.renew(1, 0));
        device.up = true; core.tick(1); assert(!device.up);
        core.release(1); assert(device.up);
    }
    { // Respect an interface the user already disabled before the stream.
        Interface device; device.up = false; auto core = device.core();
        assert(core.renew(1, 0)); device.up = true; core.tick(1);
        core.release(1); assert(!device.up && !device.marker);
    }
    { // Daemon restart recovers a journal left by an interrupted process.
        Interface device; device.up = false; device.marker = true;
        auto core = device.core(true); assert(core.restore());
        assert(device.up && !device.marker);
    }
    { // Restoration failure is retried; no new suppression before recovery.
        Interface device; auto core = device.core(); assert(core.renew(1, 0));
        device.setFails = true; assert(!core.release(1));
        assert(core.restorationPending() && !core.renew(2, 2));
        device.setFails = false; core.tick(3);
        assert(device.up && !device.marker && !core.restorationPending());
    }
    { // No state change without durable recovery bookkeeping.
        Interface device; device.journalFails = true; auto core = device.core();
        assert(!core.renew(1, 0)); assert(device.up && core.activeCount() == 0);
    }
    { // Unsupported hardware and failed operations never acquire leases.
        Interface device; device.present = false; auto core = device.core();
        assert(!core.renew(1, 0)); assert(core.activeCount() == 0);
        device.present = true; device.setFails = true;
        assert(!core.renew(1, 0)); assert(core.activeCount() == 0);
        device.setFails = false; core.tick(1); assert(!device.marker);
    }
    { // A disappeared interface recovers once it becomes available again.
        Interface device; auto core = device.core(); assert(core.renew(1, 0));
        device.present = false; assert(!core.release(1));
        device.present = true; core.tick(1); assert(device.up && !device.marker);
    }
    { // Bound resources and retain recovery across journal cleanup failures.
        Interface device; auto core = device.core();
        for (unsigned long owner = 1; owner <= 16; owner++) assert(core.renew(owner, 0));
        assert(!core.renew(17, 0)); device.journalFails = true; core.tick(16);
        assert(device.up && core.restorationPending());
        device.journalFails = false; core.tick(17); assert(!device.marker);
    }
    std::cout << "PASS: AWDL leases, crash expiry, restoration, enforcement and failure recovery\n";
}
