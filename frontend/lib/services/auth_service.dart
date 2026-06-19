import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AuthResult {
  const AuthResult({
    required this.token,
    required this.username,
    required this.phoneNumber,
    this.userId,
  });

  final String token;
  final String username;
  final String phoneNumber;
  final String? userId;
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'user_username';
  static const _phoneKey = 'user_phone';
  static const _userIdKey = 'user_id';

  Future<AuthResult> signup({
    required String username,
    required String phoneNumber,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.signupUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'phoneNumber': phoneNumber.trim(),
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  Future<void> saveSession(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.token);
    await prefs.setString(_usernameKey, result.username);
    await prefs.setString(_phoneKey, result.phoneNumber);
    if (result.userId != null) {
      await prefs.setString(_userIdKey, result.userId!);
    }
  }

  Future<void> updateStoredProfile(String username, String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_phoneKey, phoneNumber);
  }


  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<String?> getStoredPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_userIdKey);
  }

  AuthResult _handleResponse(http.Response response) {
    final Map<String, dynamic> body = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = body['token'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Invalid response from server.');
      }

      final user = body['user'];
      if (user is Map<String, dynamic>) {
        return AuthResult(
          token: token,
          username: user['username']?.toString() ?? '',
          phoneNumber: user['phoneNumber']?.toString() ?? '',
          userId: user['id']?.toString() ?? user['_id']?.toString(),
        );
      }

      return AuthResult(
        token: token,
        username: body['username']?.toString() ?? '',
        phoneNumber: body['phoneNumber']?.toString() ?? '',
      );
    }

    throw AuthException(_extractErrorMessage(body, response.statusCode));
  }

  Map<String, dynamic> _decodeBody(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    for (final key in ['message', 'error', 'msg']) {
      final value = body[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return 'Request failed ($statusCode).';
  }
}
