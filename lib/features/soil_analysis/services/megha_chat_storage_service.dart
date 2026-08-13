import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessageModel {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class MeghaChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatMessageModel> messages;

  const MeghaChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory MeghaChatSession.fromJson(Map<String, dynamic> json) =>
      MeghaChatSession(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Agricultural Chat',
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class MeghaChatStorageService {
  MeghaChatStorageService._();
  static final MeghaChatStorageService instance = MeghaChatStorageService._();

  static const String _storageKey = 'megha_chat_sessions_v1';

  Future<List<MeghaChatSession>> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      final sessions = decoded
          .map((item) => MeghaChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
      // Sort newest first
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSession(MeghaChatSession session) async {
    try {
      final sessions = await loadSessions();
      final index = sessions.indexWhere((s) => s.id == session.id);
      if (index != -1) {
        sessions[index] = session;
      } else {
        sessions.insert(0, session);
      }

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final sessions = await loadSessions();
      sessions.removeWhere((s) => s.id == sessionId);
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }
}
