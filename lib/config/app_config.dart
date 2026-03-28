class AppConfig {
  const AppConfig._();

  // Override with:
  // flutter run --dart-define=API_BASE_URL=https://your-api/api/v1/mobile
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1/mobile',
  );
}
