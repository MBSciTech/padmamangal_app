import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class FamilyEvent {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String category; // birthday|anniversary|festival|meeting|reminder|other
  final bool isRecurringYearly;
  final String createdByName;

  const FamilyEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.category,
    this.isRecurringYearly = false,
    this.createdByName = '',
  });

  factory FamilyEvent.fromJson(Map<String, dynamic> json) => FamilyEvent(
        id: json['_id']?.toString() ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        dateTime: DateTime.tryParse(json['dateTime']?.toString() ?? '') ?? DateTime.now(),
        category: json['category'] ?? 'other',
        isRecurringYearly: json['isRecurringYearly'] ?? false,
        createdByName: json['createdByName'] ?? '',
      );
}

// ─── Color mapping (used in UI) ───────────────────────────────────────────────
class EventColors {
  static const Map<String, int> colors = {
    'birthday':    0xFFEC407A,
    'anniversary': 0xFFEF5350,
    'festival':    0xFFFF7043,
    'meeting':     0xFF5C6BC0,
    'reminder':    0xFF7E57C2,
    'other':       0xFF26A69A,
  };

  static int colorFor(String category) =>
      colors[category] ?? colors['other']!;
}

// ─── Service ──────────────────────────────────────────────────────────────────
class EventService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<FamilyEvent>> fetchEvents() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/events'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((j) => FamilyEvent.fromJson(j)).toList();
    }
    throw Exception('Failed to fetch events (${res.statusCode})');
  }

  Future<FamilyEvent> createEvent({
    required String title,
    required String description,
    required DateTime dateTime,
    required String category,
    bool isRecurringYearly = false,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/events'),
      headers: await _headers(),
      body: json.encode({
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'category': category,
        'isRecurringYearly': isRecurringYearly,
      }),
    );
    if (res.statusCode == 201) {
      return FamilyEvent.fromJson(json.decode(res.body));
    }
    throw Exception('Failed to create event (${res.statusCode})');
  }

  Future<void> deleteEvent(String id) async {
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/events/$id'),
      headers: await _headers(),
    );
  }
}
