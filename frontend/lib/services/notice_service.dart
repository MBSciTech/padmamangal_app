import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class Notice {
  final String id;
  final String title;
  final String body;
  final String postedBy;
  final DateTime postedAt;
  final String priority; // 'low' | 'medium' | 'high'

  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.postedBy,
    required this.postedAt,
    required this.priority,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: json['_id']?.toString() ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        postedBy: json['postedByName'] ?? 'Unknown',
        postedAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        priority: json['priority'] ?? 'low',
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────
class NoticeService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Notice>> fetchNotices() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notices'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((j) => Notice.fromJson(j)).toList();
    }
    throw Exception('Failed to fetch notices (${res.statusCode})');
  }

  Future<Notice> createNotice({
    required String title,
    required String body,
    required String priority,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/notices'),
      headers: await _headers(),
      body: json.encode({'title': title, 'body': body, 'priority': priority}),
    );
    if (res.statusCode == 201) {
      return Notice.fromJson(json.decode(res.body));
    }
    throw Exception('Failed to create notice (${res.statusCode})');
  }

  Future<void> deleteNotice(String id) async {
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/notices/$id'),
      headers: await _headers(),
    );
  }
}
