/// The build identifier surfaced in-app so a deployed (Flutter web) build can
/// be told apart from a cached one on the device. Injected at build time by
/// the deploy workflow via `--dart-define=BUILD_TAG=<commit sha>`; falls back
/// to `dev` for local runs that don't pass it.
const String _buildTag = String.fromEnvironment('BUILD_TAG', defaultValue: 'dev');

/// A short, display-friendly build id: the first 7 chars of the commit SHA
/// (like `git log --oneline`), or `dev` locally.
String get buildLabel =>
    _buildTag.length > 7 ? _buildTag.substring(0, 7) : _buildTag;
