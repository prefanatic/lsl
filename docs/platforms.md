# Platform configuration

The build hook compiles and bundles liblsl. The application controls permissions and resource lifetime.
`lsl_flutter` supplies Android multicast locks and their normal manifest permissions.

## Build targets

Use Dart 3.13 or later. Flutter applications need Flutter 3.47 or later.
Install the target C++17 toolchain.

| Target | Architectures | Toolchain |
| --- | --- | --- |
| Android | armv7, arm64, x64 | Android SDK and NDK |
| iOS | arm64 device; arm64 or x64 simulator | Xcode and the target SDK |
| Linux | arm64, x64 | GCC or Clang, C++ standard library, pthreads |
| macOS | arm64, x64 | Xcode command line tools |
| Windows | arm64, x64 | Visual Studio with Desktop development with C++ |

These are build targets; see [verification](verification.md) for tested architectures.
Cross-compilation requires a host toolchain that Dart or Flutter supports.
The example uses Android API 24, iOS 15, and macOS 12 as deployment minimums.
A consuming application must also meet its Flutter SDK's platform minimums.
Web is not supported.

## Network access

LSL uses UDP discovery, TCP sample transfer, and UDP clock synchronization.
Firewalls must permit the relevant local network traffic.
The default discovery port is 16571. Stream ports depend on the LSL configuration.
The default port range starts at 16572 and contains 32 ports.
See the [LSL network overview](https://labstreaminglayer.readthedocs.io/projects/liblsl/internals/overview.html).
LSL does not encrypt samples or authenticate peers. Use a network with appropriate access controls.

## Android

Flutter applications acquire `LslMulticastLock` before LSL work and release it when that work stops.
The `lsl_flutter` plugin supplies Internet, Wi-Fi state, and multicast manifest permissions.
Each caller owns one lock. The plugin holds native access until the last caller releases its lock.
The plugin also releases native access when the Flutter engine closes.
Other platforms need no native multicast lock, so this API has no effect there.

```dart
final multicast = await LslMulticastLock.acquire();
try {
  // Create and use LSL resources here, then destroy them.
} finally {
  await multicast.release();
}
```

The package does not request runtime permissions.
Pure Dart Android hosts must declare the normal permissions and manage `WifiManager.MulticastLock` themselves.
The application must provide any required Android background service.
See [Android's MulticastLock documentation](https://developer.android.com/reference/android/net/wifi/WifiManager.MulticastLock).

Apps that target Android 17 (SDK 37) or later must also declare `android.permission.ACCESS_LOCAL_NETWORK`.
Request that permission at runtime before LSL creates an inlet or outlet, or starts discovery.
Handle permission denial and revocation in the application.
Apps that target SDK 36 or earlier use `INTERNET` for this access.
The example follows Flutter 3.47's SDK 36 target and does not request the newer permission.
See [Android's local network permission guidance](https://developer.android.com/privacy-and-security/local-network-permission).

The hook links the C++ runtime statically and requests 16 KiB ELF page alignment through `native_toolchain_c`.

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

## Linux and Windows

Install the target C++17 toolchain.
Allow local UDP and TCP traffic through the host firewall.
The hook builds a shared library and the Dart or Flutter tool bundles it.
The application needs no system-wide liblsl installation.
Windows uses the Visual Studio toolchain and the system socket libraries.
Linux uses the target C++ runtime and pthreads.

## Device checks

Test discovery, clock correction, and sample transfer on the intended network before a mobile release.
Test local network permission prompts, denial, and revocation on physical devices.
Simulator tests verify transport within one simulated device; they do not establish discovery between separate devices.
See [verification](verification.md) for recorded results and remaining limits.
