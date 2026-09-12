/// Build-time configuration values that differ between a developer's own
/// build and the published Play Store release, supplied via --dart-define
/// (see .github/workflows/build.yml and the README). Kept separate from
/// AdsService's ad unit IDs since this covers non-ad configuration.
class AppConfig {
  AppConfig._();

  /// V2 major release version. Keep this aligned with pubspec.yaml.
  static const String version = '2.0.0';
  static const int versionCode = 12;

  /// Hosted Privacy Policy URL. Required by Google Play before publishing.
  /// Empty by default so Settings can honestly show "not configured yet"
  /// instead of a dead link.
  static const String privacyPolicyUrl =
      String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: '');

  /// Syncfusion license key for the PDF engine + reader viewer. Empty by
  /// default, which puts Syncfusion's widgets in trial mode (visible
  /// watermark). Syncfusion offers a free Community License for
  /// qualifying individuals/small businesses — see README for setup.
  static const String syncfusionLicenseKey =
      String.fromEnvironment('SYNCFUSION_LICENSE_KEY', defaultValue: '');
}
