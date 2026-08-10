/// Where the Node.js backend lives.
///
/// Passed at build time so the same binary can point at a local server, a
/// staging container app, or production without a code change:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///   flutter build apk --dart-define=API_BASE_URL=https://docflow-api...azurecontainerapps.io
///
/// The default is the Android emulator's alias for the host machine, which is
/// the case that would otherwise silently fail against localhost.
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Conversions run through LibreOffice on the server and can genuinely take
  /// a while on a large document. The backend's own ceiling is 120s.
  static const Duration conversionTimeout = Duration(seconds: 180);

  /// Quota and profile reads should feel instant or be treated as offline.
  static const Duration readTimeout = Duration(seconds: 15);
}
