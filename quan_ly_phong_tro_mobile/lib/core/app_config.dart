class AppConfig {
  // Android Emulator: http://10.0.2.2:5129/api
  // Dien thoai that: flutter run --dart-define=API_BASE_URL=http://IP_MAY_TINH:5129/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5129/api',
  );
}
