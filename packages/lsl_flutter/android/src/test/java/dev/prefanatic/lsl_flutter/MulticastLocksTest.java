// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.
package dev.prefanatic.lsl_flutter;

import android.content.Context;
import android.net.wifi.WifiManager;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowWifiManager;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class MulticastLocksTest {
    private MulticastLocks locks;
    private ShadowWifiManager wifi;

    @Before
    public void setUp() {
        final WifiManager manager = (WifiManager) RuntimeEnvironment.getApplication()
            .getSystemService(Context.WIFI_SERVICE);
        wifi = Shadows.shadowOf(manager);
        locks = new MulticastLocks(manager);
    }

    @After
    public void tearDown() { locks.close(); }

    @Test
    public void eachCallerKeepsAccessUntilItReleases() {
        final long first = locks.acquire();
        final long second = locks.acquire();
        assertNotEquals(first, second);
        assertEquals(1, wifi.getActiveLockCount());
        locks.release(first);
        assertEquals(1, wifi.getActiveLockCount());
        locks.release(first);
        assertEquals(1, wifi.getActiveLockCount());
        locks.release(second);
        assertEquals(0, wifi.getActiveLockCount());
    }

    @Test
    public void engineCloseReleasesAllCallers() {
        locks.acquire();
        locks.acquire();
        locks.close();
        locks.close();
        assertEquals(0, wifi.getActiveLockCount());
    }

    @Test
    public void anOldHandleCannotReleaseANewLock() {
        final long first = locks.acquire();
        locks.release(first);
        final long second = locks.acquire();
        locks.release(first);
        locks.release(999);
        assertEquals(1, wifi.getActiveLockCount());
        locks.release(second);
        assertEquals(0, wifi.getActiveLockCount());
    }

    @Test
    public void aMissingWifiServiceFailsBeforeOwnership() {
        final MulticastLocks unavailable = new MulticastLocks(null);
        assertThrows(SecurityException.class, unavailable::acquire);
        unavailable.close();
        assertEquals(0, wifi.getActiveLockCount());
    }
}
