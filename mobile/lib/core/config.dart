class AppConfig {
  /// Override at build time:
  /// flutter run --dart-define=API_URL=https://api.atmaen.sa
  /// Android emulator reaches the host machine on 10.0.2.2
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

  static String get wsUrl => apiUrl.replaceFirst(RegExp(r'^http'), 'ws');

  static const emergencyNumber = '997';
  static const medicalLine = '937';
}
