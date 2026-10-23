// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.
package dev.prefanatic.lsl_example

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onStart() {
        super.onStart()
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        multicastLock = wifi.createMulticastLock("lsl-example").apply { acquire() }
    }

    override fun onStop() {
        multicastLock?.release()
        multicastLock = null
        super.onStop()
    }
}
