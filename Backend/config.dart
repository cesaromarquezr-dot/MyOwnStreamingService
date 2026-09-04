class AppConfig {
  static const String host = '127.0.0.1';
  static const int port = 8080;

  static const String apiVersion = 'v1';

  static String get baseUrl => 'http://$host:$port';

  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';
}