import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'event.dart';

/// Collects non-PII device context once on init.
class ContextCollector {
  EventContext? _cached;

  /// Returns the cached context, collecting it if needed.
  Future<EventContext> collect() async {
    if (_cached != null) return _cached!;

    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String os;
    String osVersion;
    String deviceType;

    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      os = 'iOS';
      osVersion = ios.systemVersion;
      deviceType = ios.utsname.machine;
    } else if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      os = 'Android';
      osVersion = android.version.release;
      deviceType = '${android.manufacturer} ${android.model}';
    } else {
      os = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
      deviceType = 'unknown';
    }

    final view = PlatformDispatcher.instance.views.first;
    final logicalSize = view.physicalSize / view.devicePixelRatio;

    _cached = EventContext(
      os: os,
      osVersion: osVersion,
      appVersion: packageInfo.version,
      locale: PlatformDispatcher.instance.locale.toString(),
      deviceType: deviceType,
      screenWidth: logicalSize.width.round(),
      screenHeight: logicalSize.height.round(),
    );

    return _cached!;
  }

  /// Clears the cached context (for testing).
  void reset() => _cached = null;
}
