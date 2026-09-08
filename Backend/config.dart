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