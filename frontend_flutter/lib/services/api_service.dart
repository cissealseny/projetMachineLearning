import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/predict_models.dart';

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'http://127.0.0.1:8000/api';

  final http.Client _client;
  final String _baseUrl;
  String? _accessToken;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> _authHeaders() {
    if (!isAuthenticated) {
      throw Exception('Utilisateur non authentifie. Connectez-vous d abord.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };
  }

  void logout() {
    _accessToken = null;
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login/');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = (json['access'] ?? '').toString();
      if (token.isEmpty) {
        throw Exception('Access token manquant dans la reponse.');
      }
      _accessToken = token;
      return;
    }

    throw Exception('Login failed: ${response.statusCode} ${response.body}');
  }

  Future<void> register({
    required String username,
    required String password,
    required String email,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register/');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'email': email,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = (json['access'] ?? '').toString();
      if (token.isEmpty) {
        throw Exception('Access token manquant dans la reponse.');
      }
      _accessToken = token;
      return;
    }

    throw Exception(
        'Inscription failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> quickLogin({
    String username = 'demo',
    String password = 'Demo12345!',
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/dev-quick-login/');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = (json['access'] ?? '').toString();
      if (token.isEmpty) {
        throw Exception('Access token manquant dans la reponse quick login.');
      }
      _accessToken = token;
      return json;
    }

    throw Exception(
      'Quick login failed: ${response.statusCode} ${response.body}',
    );
  }

  Future<Map<String, dynamic>> health() async {
    final uri = Uri.parse('$_baseUrl/health/');
    final response = await _client.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Health check failed: ${response.statusCode}');
  }

  Future<PredictResponse> predict(PredictRequest request) async {
    final uri = Uri.parse('$_baseUrl/predict/');
    final response = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PredictResponse.fromJson(json);
    }

    throw Exception(
      'Prediction failed: ${response.statusCode} ${response.body}',
    );
  }

  Future<Map<String, dynamic>> dashboard() async {
    final uri = Uri.parse('$_baseUrl/dashboard/');
    final response = await _client.get(uri, headers: _authHeaders());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Dashboard fetch failed: ${response.statusCode} ${response.body}',
    );
  }

  Future<List<dynamic>> predictionHistory() async {
    final uri = Uri.parse('$_baseUrl/predictions/history/');
    final response = await _client.get(uri, headers: _authHeaders());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception(
      'History fetch failed: ${response.statusCode} ${response.body}',
    );
  }

  Future<Map<String, dynamic>> publicTunisiaDashboard() async {
    final uri = Uri.parse('$_baseUrl/public/tunisia-dashboard/');
    final response = await _client.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Public dashboard fetch failed: ${response.statusCode} ${response.body}',
    );
  }
}
