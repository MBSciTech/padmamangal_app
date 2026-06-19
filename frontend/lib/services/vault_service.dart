import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import 'chat_service.dart' show ChatFile;

class VaultDocument {
  final String id;
  final String name;
  final String type;
  final String uploaderId;
  final int size;
  final DateTime createdAt;

  VaultDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.uploaderId,
    required this.size,
    required this.createdAt,
  });

  factory VaultDocument.fromJson(Map<String, dynamic> json) {
    return VaultDocument(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Document',
      type: json['type']?.toString() ?? 'file',
      uploaderId: json['uploaderId']?.toString() ?? '',
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
    );
  }
}

class VaultService {
  final AuthService _authService = AuthService();

  Future<List<VaultDocument>> fetchDocuments() async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/vault'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => VaultDocument.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to fetch vault documents';
      throw Exception(errMsg);
    }
  }

  Future<VaultDocument> uploadDocument(ChatFile file) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/vault'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(file.toJson()),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      return VaultDocument.fromJson(body);
    } else {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to upload document';
      throw Exception(errMsg);
    }
  }

  Future<ChatFile> downloadDocument(String id) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/vault/$id/download'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      return ChatFile.fromJson(body);
    } else {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to download document';
      throw Exception(errMsg);
    }
  }

  Future<void> deleteDocument(String id) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/vault/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to delete document';
      throw Exception(errMsg);
    }
  }

  Map<String, dynamic> _safeDecode(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}
