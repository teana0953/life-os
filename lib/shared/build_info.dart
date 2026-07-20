/// The app version shown in-app, in standard semver form
/// `MAJOR.MINOR.PATCH+BUILD`. The version comes from `pubspec.yaml` and the
/// build number is the CI run number, both injected at build time by the
/// deploy workflow via `--dart-define`. Falls back to a local placeholder when
/// not provided. The build number increments on every deploy, so it also tells
/// a freshly-deployed build apart from a cached one on the device.
const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);
const String _buildNumber = String.fromEnvironment(
  'BUILD_NUMBER',
  defaultValue: 'dev',
);

/// Display label in standard semver form, e.g. `1.0.0+42` (or `1.0.0+dev`
/// for local builds without a CI build number).
String get buildLabel => '$_appVersion+$_buildNumber';
