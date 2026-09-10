import 'dart:io';

class AppConfig {
  // ---------------------------------------------------------------------------
  // SERVER
  // ---------------------------------------------------------------------------

  static const String host =
      '127.0.0.1';

  static const int port = 8080;

  static const String apiVersion =
      'v1';

  static String get baseUrl {
    return 'http://$host:$port';
  }

  static String get apiBaseUrl {
    return '$baseUrl/api/$apiVersion';
  }

  // ARM
  // Set ARM_SERVER_URL in the backend environment to the ARM web UI,
  // for example http://192.168.1.50:8080.
  static String get armServerUrl =>
      Platform.environment['ARM_SERVER_URL']?.trim().isNotEmpty == true
          ? Platform.environment['ARM_SERVER_URL']!.trim()
          : 'http://127.0.0.1:8081';

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  // Absolute lifetime of a normal login session.
  //
  // Later we can make this configurable per device/trust level.
  static const Duration sessionLifetime =
      Duration(days: 30);

  // Minimum password length for the first
  // authentication implementation.
  //
  // We will strengthen the password policy in
  // the next authentication pass.
  static const int minimumPasswordLength =
      6;
}