class AppConfig {
  const AppConfig._();

  /// Production defaults so Play Store / CI builds never ship pointing at the
  /// emulator loopback. Override for local backend:
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1/mobile`
  /// `--dart-define=PUBLIC_API_BASE_URL=http://10.0.2.2:3000`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.dukanest.com/api/v1/mobile',
  );

  // Base host used by public/non-mobile-envelope endpoints like
  // GET /api/tenants/check-subdomain and POST /api/tenants/register.
  static const String publicApiBaseUrl = String.fromEnvironment(
    'PUBLIC_API_BASE_URL',
    defaultValue: 'https://www.dukanest.com',
  );

  /// Google OAuth 2.0 **Web application** client ID (`*.apps.googleusercontent.com`).
  /// Required on Android for `google_sign_in` 7.x to return an [idToken] for
  /// `POST /api/v1/mobile/auth/google`. Use the **Web** client from Google Cloud
  /// Console → APIs & Services → Credentials — the same one Supabase shows for
  /// the Google provider (not the Android/iOS client-only ID).
  ///
  /// ```sh
  /// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=123456....apps.googleusercontent.com
  /// ```
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    // OAuth client IDs are public identifiers. Keep this as a fallback so
    // release builds cannot accidentally ship without Google Sign-In enabled.
    defaultValue:
        '772287815251-eb8r1f4bqpudek9pubvnrm36tnv9js05.apps.googleusercontent.com',
  );
}
