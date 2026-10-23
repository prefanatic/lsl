# Platform configuration

The build hook packages native code. The application controls network access and lifecycle.
LSL uses UDP discovery, TCP sample transfer, and UDP clock synchronization.
Firewalls must permit the relevant local network traffic.
The default discovery port is 16571. Stream ports depend on the LSL configuration.
See the [LSL network overview](https://labstreaminglayer.readthedocs.io/projects/liblsl/internals/overview.html).

## Android

Add these permissions to the application's main manifest:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

Acquire a `WifiManager.MulticastLock` while the application needs Wi-Fi multicast reception.
Release the lock when that work stops.
The example activity shows this lifecycle for a foreground application.
The package does not hold a global lock or create an Android background service.
See [Android's MulticastLock documentation](https://developer.android.com/reference/android/net/wifi/WifiManager.MulticastLock).

The hook builds armv7, arm64, and x64 targets with the NDK compiler.
It links the C++ runtime statically and requests 16 KiB ELF page alignment through `native_toolchain_c`.
Physical-device tests must verify discovery and sample transfer across the intended Wi-Fi networks.

## iOS

Add `NSLocalNetworkUsageDescription` to the application's `Info.plist`.
Explain why the application needs access to the local network.
For multicast discovery, request the `com.apple.developer.networking.multicast` entitlement from Apple.
Use a signing profile that contains that entitlement.
The example declares it but contains no development team or signing credentials.

See [Apple's local network guidance](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
and [Apple's multicast entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast).
A simulator build does not verify the permission prompt or multicast on a physical device.
The package does not provide an iOS background execution mode.

## macOS

Add `NSLocalNetworkUsageDescription` to the application's `Info.plist`.
A sandboxed application needs these entitlements in each build configuration:

```xml
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.network.server</key><true/>
```

The example includes these entitlements for debug, profile, and release builds.
The hook builds a library for the selected architecture.

## Linux and Windows

Install the target C++17 toolchain.
Allow local UDP and TCP traffic through the host firewall.
The hook builds a shared library and the Dart or Flutter tool bundles it.
The application needs no system-wide liblsl installation.
Windows uses the Visual Studio toolchain and the system socket libraries.
The build enables `/EHsc` so C++ timeout exceptions release native locks during stack unwinding.
See [Microsoft's exception model](https://learn.microsoft.com/en-us/cpp/build/reference/eh-exception-handling-model).
Linux uses the target C++ runtime and pthreads.

## Scope of support

The hook validates operating system and architecture combinations before a download.
Cross-compilation still requires the host toolchain that Dart or Flutter supports.
The CI workflow tests desktop hosts and builds the example for desktop, Android, and the iOS simulator.
Run physical-device tests before a release that claims validated mobile discovery.
