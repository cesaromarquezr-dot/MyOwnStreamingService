import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  BackendApiException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'BackendApiException ($statusCode): $message';
    }

    return 'BackendApiException: $message';
  }
}

class BackendApi {
  final String baseUrl;

  String? _token;

  BackendApi({
    this.baseUrl = 'http://127.0.0.1:8080/api/v1',
  });

  String? get token => _token;

  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (isAuthenticated) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
    required String firstProfileName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'firstProfileName': firstProfileName,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to create account.',
        statusCode: response.statusCode,
      );
    }

    final token = data['token']?.toString();

    if (token != null && token.isNotEmpty) {
      setToken(token);
    }

    return data;
  }

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to log in.',
        statusCode: response.statusCode,
      );
    }

    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      throw BackendApiException(
        'Backend login succeeded but no authentication token was returned.',
        statusCode: response.statusCode,
      );
    }

    setToken(token);

    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve account.',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  Future<void> logout() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headers,
      );
    } finally {
      clearToken();
    }
  }

  Future<List<dynamic>> getArmDrives() async {
    final response = await http.get(
      Uri.parse('$baseUrl/arm/drives'),
      headers: _headers,
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw BackendApiException(
        data['error']?.toString() ??
            'Unable to retrieve ARM drives.',
        statusCode: response.statusCode,
      );
    }

    final drives = data['drives'];

    if (drives is List) {
      return drives;
    }

    return [];
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.body.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'data': decoded,
      };
    } catch (_) {
      return {
        'error': response.body,
      };
    }
  }
}