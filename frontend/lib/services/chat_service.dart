import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ChatFile {
  final String data; // Base64 data string
  final String name; // Filename
  final String type; // 'image' | 'video' | 'voice' | 'file'

  ChatFile({required this.data, required this.name, required this.type});

  factory ChatFile.fromJson(Map<String, dynamic> json) {
    return ChatFile(
      data: json['data']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data,
        'name': name,
        'type': type,
      };
}

class MessageReaction {
  final String userId;
  final String username;
  final String emoji;

  MessageReaction({required this.userId, required this.username, required this.emoji});

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
    );
  }
}

class ChatLocation {
  final double latitude;
  final double longitude;
  final bool isLive;
  final DateTime? liveExpiresAt;

  ChatLocation({
    required this.latitude,
    required this.longitude,
    required this.isLive,
    this.liveExpiresAt,
  });

  factory ChatLocation.fromJson(Map<String, dynamic> json) {
    return ChatLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isLive: json['isLive'] as bool? ?? false,
      liveExpiresAt: json['liveExpiresAt'] != null
          ? DateTime.parse(json['liveExpiresAt']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'isLive': isLive,
        'liveExpiresAt': liveExpiresAt?.toUtc().toIso8601String(),
      };
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final String? senderProfilePic;
  final ChatFile? file;
  final ChatLocation? location;
  final List<MessageReaction> reactions;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.senderProfilePic,
    this.file,
    this.location,
    required this.reactions,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final fileData = json['file'];
    final locationData = json['location'];
    final reactionsData = json['reactions'] as List<dynamic>?;

    return ChatMessage(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Unknown',
      message: json['message']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      senderProfilePic: json['senderProfilePic']?.toString(),
      file: fileData is Map<String, dynamic> ? ChatFile.fromJson(fileData) : null,
      location: locationData is Map<String, dynamic> ? ChatLocation.fromJson(locationData) : null,
      reactions: reactionsData != null
          ? reactionsData
              .map((dynamic item) => MessageReaction.fromJson(item as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class ChatService {
  final AuthService _authService = AuthService();

  Future<List<ChatMessage>> fetchMessages() async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to fetch messages';
      throw Exception(errMsg);
    }
  }

  Future<ChatMessage> sendMessage(String text, {ChatFile? file, ChatLocation? location}) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final Map<String, dynamic> requestBody = {
      'message': text.trim(),
    };
    if (file != null) {
      requestBody['file'] = file.toJson();
    }
    if (location != null) {
      requestBody['location'] = location.toJson();
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      return ChatMessage.fromJson(body);
    } else {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to send message';
      throw Exception(errMsg);
    }
  }

  Future<List<MessageReaction>> reactToMessage(String messageId, String emoji) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$messageId/react'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'emoji': emoji}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> reactionsList = body['reactions'] ?? [];
      return reactionsList
          .map((dynamic item) => MessageReaction.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to update reaction';
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

  Future<void> updateLiveLocation(String messageId, double latitude, double longitude) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$messageId/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorBody = _safeDecode(response.body);
      final errMsg = errorBody['message'] ?? 'Failed to update live location';
      throw Exception(errMsg);
    }
  }
}
