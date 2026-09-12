import 'package:flutter/services.dart';

/// Opens this app's system "App info" settings screen via a small native
/// MethodChannel (see MainActivity.kt), instead of relying on the
/// permission_handler package's `openAppSettings()`.
///
/// Opening `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` requires no
/// Android permission declaration at all, so this introduces nothing into
/// the merged manifest.
class AppSettingsOpener {
  AppSettingsOpener._();

  static const MethodChannel _channel =
      MethodChannel('com.hameed.pdfmastertools/app_settings');

  static Future<void> open() async {
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
    } on PlatformException {
      // No-op: if the platform call fails there is nothing else we can
      // do from Dart without adding a permission-bearing dependency.
    }
  }
}
