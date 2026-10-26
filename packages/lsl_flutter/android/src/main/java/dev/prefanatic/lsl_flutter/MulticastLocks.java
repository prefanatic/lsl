// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.
package dev.prefanatic.lsl_flutter;

import android.net.wifi.WifiManager;
import java.util.HashSet;
import java.util.Set;

/** Shares one native lock across callers on one Flutter engine. */
final class MulticastLocks {
    private final WifiManager wifi;
    private final Set<Long> owners = new HashSet<>();
    private WifiManager.MulticastLock lock;
    private long nextId = 0;

    MulticastLocks(WifiManager wifi) {
        this.wifi = wifi;
    }

    long acquire() {
        if (lock == null) {
            if (wifi == null) throw new SecurityException("Wi-Fi is unavailable.");
            final WifiManager.MulticastLock candidate = wifi.createMulticastLock("lsl_flutter");
            candidate.setReferenceCounted(false);
            candidate.acquire();
            lock = candidate;
        }
        final long id = ++nextId;
        owners.add(id);
        return id;
    }

    void release(long id) {
        if (!owners.contains(id)) return;
        if (owners.size() == 1) releaseNativeLock();
        owners.remove(id);
    }

    void close() {
        releaseNativeLock();
        owners.clear();
    }

    private void releaseNativeLock() {
        if (lock != null && lock.isHeld()) lock.release();
        lock = null;
    }
}
