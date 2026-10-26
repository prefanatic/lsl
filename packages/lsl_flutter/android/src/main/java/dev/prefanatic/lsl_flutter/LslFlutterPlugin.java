// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.
package dev.prefanatic.lsl_flutter;

import android.content.Context;
import android.net.wifi.WifiManager;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Owns multicast resources for one Flutter engine. */
public final class LslFlutterPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private MulticastLocks locks;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        final Context context = binding.getApplicationContext();
        locks = new MulticastLocks((WifiManager) context.getSystemService(Context.WIFI_SERVICE));
        channel = new MethodChannel(binding.getBinaryMessenger(), "dev.prefanatic.lsl_flutter/multicast");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "acquire":
                    result.success(locks.acquire());
                    break;
                case "release":
                    if (!(call.arguments instanceof Number)) {
                        result.error("invalid_argument", "Expected a lock identifier.", null);
                        return;
                    }
                    locks.release(((Number) call.arguments).longValue());
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
            }
        } catch (SecurityException error) {
            result.error("multicast_unavailable", "Wi-Fi multicast access is unavailable.", null);
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        locks.close();
        locks = null;
    }
}
