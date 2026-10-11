#pragma once
#include <functional>
#include <optional>
#include <string>
#include <unordered_map>

// Platform-independent state machine. Only the daemon's serial queue uses it.
// A lease is renewed every 5 seconds and expires after 15 seconds, including
// when a frontend crashes or its XPC connection stops responding.
class AWDLLeaseCore {
public:
    using Read = std::function<std::optional<bool>()>;
    using Set = std::function<bool(bool)>;
    using Journal = std::function<bool(bool)>;
    AWDLLeaseCore(Read read, Set set, Journal journal, bool recoveryPending = false)
        : read_(read), set_(set), journal_(journal), restorePending_(recoveryPending) {}

    bool renew(unsigned long owner, double now) {
        if (leases_.empty()) {
            if (!restore()) return false;
            auto up = read_();
            if (!up) return fail("AWDL is unavailable on this Mac.");
            if (*up) {
                // Persist the recovery obligation BEFORE changing the interface.
                if (!journal_(true)) return fail("Could not save AWDL recovery state.");
                restorePending_ = true;
                if (!set_(false)) {
                    restore();
                    return fail("Could not disable AWDL. Streaming is unaffected.");
                }
            }
        }
        if (leases_.count(owner) == 0 && leases_.size() >= 16)
            return fail("Too many AWDL sessions.");
        leases_[owner] = now + 15.0;
        error.clear();
        return true;
    }
    bool release(unsigned long owner) {
        leases_.erase(owner);
        return !leases_.empty() || restore();
    }
    void tick(double now) {
        for (auto it = leases_.begin(); it != leases_.end();) {
            if (it->second <= now) it = leases_.erase(it); else ++it;
        }
        if (leases_.empty()) { restore(); return; }
        auto up = read_();
        if (!up) { fail("AWDL interface became unavailable."); return; }
        if (*up && !set_(false)) fail("Could not keep AWDL disabled.");
        else error.clear();
    }
    bool restore() {
        if (!restorePending_) return true;
        auto up = read_();
        if (!up || (!*up && !set_(true)))
            return fail("AWDL restoration failed; the helper will retry.");
        if (!journal_(false)) return fail("Could not clear AWDL recovery state.");
        restorePending_ = false;
        error.clear();
        return true;
    }
    size_t activeCount() const { return leases_.size(); }
    bool restorationPending() const { return restorePending_; }
    std::string error;
private:
    bool fail(const char* text) { error = text; return false; }
    Read read_;
    Set set_;
    Journal journal_;
    bool restorePending_;
    std::unordered_map<unsigned long, double> leases_;
};
