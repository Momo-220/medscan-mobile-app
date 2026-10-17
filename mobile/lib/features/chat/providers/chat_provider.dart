import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/remote/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/credits_provider.dart';

// ─── Chat mode ───────────────────────────────────────────────────────────────
// 'chat'         → normal pharmaceutical Q&A
// 'consultation' → pre-consultation symptom workflow
// ─────────────────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Ref _ref;

  /// Active mode for the next message send
  String _mode = 'chat';
  String get mode => _mode;

  /// Optional medication context injected from scan result screen
  String? _medicationContext;
  String? get medicationContext => _medicationContext;

  /// Optional medication image URL injected from scan result screen
  String? _medicationImageUrl;
  String? get medicationImageUrl => _medicationImageUrl;

  /// ChatGPT-style Session Management
  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  String _activeChatSessionId = '';
  String _activeConsultationSessionId = '';

  String get activeChatSessionId => _activeChatSessionId;
  String get activeConsultationSessionId => _activeConsultationSessionId;
  String get activeSessionId => _mode == 'consultation' ? _activeConsultationSessionId : _activeChatSessionId;

  /// Tracks cold start vs navigation within the same active app session
  static bool _coldStartChecked = false;

  ChatNotifier(this._ref) : super(const AsyncValue.data([])) {
    _initSessions();

    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _loadSessionsForUser(user.uid);
      } else {
        _loadSessionsForUser('trial');
      }
    }, fireImmediately: false);
  }

  String _currentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'trial';
  }

  void _initSessions() {
    final userId = _currentUserId();
    _loadSessionsForUser(userId);
  }

  void _loadSessionsForUser(String userId) {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);

      // 1. Load saved sessions
      final jsonStr = prefs.getChatSessionsJson(userId);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _sessions = decoded.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _sessions = [];
        // Migration: check legacy flat cache
        final legacyJson = prefs.getChatCache(userId);
        if (legacyJson != null && legacyJson.isNotEmpty) {
          try {
            final List<dynamic> list = json.decode(legacyJson);
            final legacyMessages = list.map((e) => ChatMessage.fromJson(e)).toList();
            if (legacyMessages.isNotEmpty) {
              final firstUserMsg = legacyMessages.firstWhere(
                (m) => m.role == 'user',
                orElse: () => legacyMessages.first,
              );
              final migratedSession = ChatSession(
                id: const Uuid().v4(),
                title: _deriveTitle(firstUserMsg.content),
                mode: 'chat',
                createdAt: legacyMessages.first.timestamp,
                updatedAt: legacyMessages.last.timestamp,
                messages: legacyMessages,
              );
              _sessions = [migratedSession];
              _saveSessions(userId);
            }
          } catch (_) {}
        }
      }

      // Sort sessions by descending updatedAt (newest conversations first)
      _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // 2. Determine session state: Cold start vs >30 min inactivity vs returning
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastActivity = prefs.getLastChatActivity(userId);
      final savedActiveChatId = prefs.getActiveChatSessionId(userId);
      final savedActiveConsultationId = prefs.getActiveConsultationSessionId(userId);

      final bool isColdStart = !_coldStartChecked;
      _coldStartChecked = true;

      final bool isInactiveTooLong = lastActivity != null && (now - lastActivity) > (30 * 60 * 1000);

      if (isColdStart || isInactiveTooLong || savedActiveChatId == null || savedActiveChatId.isEmpty) {
        _activeChatSessionId = const Uuid().v4();
        prefs.setActiveChatSessionId(userId, _activeChatSessionId);
      } else {
        _activeChatSessionId = savedActiveChatId;
      }

      if (isColdStart || isInactiveTooLong || savedActiveConsultationId == null || savedActiveConsultationId.isEmpty) {
        _activeConsultationSessionId = const Uuid().v4();
        prefs.setActiveConsultationSessionId(userId, _activeConsultationSessionId);
      } else {
        _activeConsultationSessionId = savedActiveConsultationId;
      }

      prefs.setLastChatActivity(userId, now);

      // Load messages for currently selected mode
      final activeId = activeSessionId;
      final matching = _sessions.where((s) => s.id == activeId);
      if (matching.isNotEmpty) {
        state = AsyncValue.data(List<ChatMessage>.from(matching.first.messages));
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (_) {
      _activeChatSessionId = const Uuid().v4();
      _activeConsultationSessionId = const Uuid().v4();
      state = const AsyncValue.data([]);
    }
  }

  void _saveSessions(String userId) {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final jsonStr = json.encode(_sessions.map((s) => s.toJson()).toList());
      prefs.setChatSessionsJson(userId, jsonStr);
    } catch (_) {}
  }

  void _touchActivity(String userId) {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      prefs.setLastChatActivity(userId, now);
      if (_mode == 'consultation') {
        prefs.setActiveConsultationSessionId(userId, _activeConsultationSessionId);
      } else {
        prefs.setActiveChatSessionId(userId, _activeChatSessionId);
      }
    } catch (_) {}
  }

  String _deriveTitle(String text) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.isEmpty) return 'Nouvelle discussion';
    if (clean.length <= 34) return clean;
    final truncated = clean.substring(0, 34);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 14) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  /// Switch between 'chat' and 'consultation' modes.
  /// Each mode is a completely independent section with its own distinct session and history.
  void setMode(String newMode) {
    if (_mode == newMode) return;
    _mode = newMode;

    final userId = _currentUserId();
    final prefs = _ref.read(sharedPrefsServiceProvider);

    if (newMode == 'consultation') {
      if (_activeConsultationSessionId.isEmpty) {
        _activeConsultationSessionId = const Uuid().v4();
        prefs.setActiveConsultationSessionId(userId, _activeConsultationSessionId);
      }
      final matching = _sessions.where((s) => s.id == _activeConsultationSessionId);
      if (matching.isNotEmpty) {
        state = AsyncValue.data(List<ChatMessage>.from(matching.first.messages));
      } else {
        state = const AsyncValue.data([]);
      }
    } else {
      if (_activeChatSessionId.isEmpty) {
        _activeChatSessionId = const Uuid().v4();
        prefs.setActiveChatSessionId(userId, _activeChatSessionId);
      }
      final matching = _sessions.where((s) => s.id == _activeChatSessionId);
      if (matching.isNotEmpty) {
        state = AsyncValue.data(List<ChatMessage>.from(matching.first.messages));
      } else {
        state = const AsyncValue.data([]);
      }
    }

    _ref.read(chatStreamingProvider.notifier).state = '';
    _touchActivity(userId);
  }

  /// Inject a medication name as context (scan-to-chat feature).
  void setMedicationContext(String? name, {String? imageUrl}) {
    _medicationContext = name;
    _medicationImageUrl = imageUrl;
  }

  /// Starts a brand new conversation session in the specified or active mode
  void startNewSession({String? mode}) {
    final targetMode = mode ?? _mode;
    _mode = targetMode;
    _medicationContext = null;
    _medicationImageUrl = null;
    state = const AsyncValue.data([]);
    _ref.read(chatStreamingProvider.notifier).state = '';

    final userId = _currentUserId();
    final prefs = _ref.read(sharedPrefsServiceProvider);

    if (targetMode == 'consultation') {
      _activeConsultationSessionId = const Uuid().v4();
      prefs.setActiveConsultationSessionId(userId, _activeConsultationSessionId);
    } else {
      _activeChatSessionId = const Uuid().v4();
      prefs.setActiveChatSessionId(userId, _activeChatSessionId);
    }

    _touchActivity(userId);
  }

  /// Loads an existing conversation from history into its appropriate mode workspace
  void loadSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final session = _sessions[index];
    _mode = session.mode;
    _medicationContext = null;
    _medicationImageUrl = null;

    final userId = _currentUserId();
    final prefs = _ref.read(sharedPrefsServiceProvider);

    if (session.mode == 'consultation') {
      _activeConsultationSessionId = session.id;
      prefs.setActiveConsultationSessionId(userId, session.id);
    } else {
      _activeChatSessionId = session.id;
      prefs.setActiveChatSessionId(userId, session.id);
    }

    state = AsyncValue.data(List<ChatMessage>.from(session.messages));
    _ref.read(chatStreamingProvider.notifier).state = '';

    _touchActivity(userId);
  }

  /// Deletes a conversation session from history
  void deleteSession(String sessionId) {
    final userId = _currentUserId();
    _sessions.removeWhere((s) => s.id == sessionId);
    _saveSessions(userId);

    final prefs = _ref.read(sharedPrefsServiceProvider);

    if (_activeChatSessionId == sessionId) {
      _activeChatSessionId = const Uuid().v4();
      prefs.setActiveChatSessionId(userId, _activeChatSessionId);
      if (_mode == 'chat') {
        state = const AsyncValue.data([]);
      }
    }
    if (_activeConsultationSessionId == sessionId) {
      _activeConsultationSessionId = const Uuid().v4();
      prefs.setActiveConsultationSessionId(userId, _activeConsultationSessionId);
      if (_mode == 'consultation') {
        state = const AsyncValue.data([]);
      }
    }

    // Re-trigger state to update UI watchers
    state = AsyncValue.data(List<ChatMessage>.from(state.value ?? []));
  }

  /// Clear the current conversation (retained for backward compatibility).
  void clearHistory() {
    startNewSession();
  }

  /// Explicitly reload history from backend.
  Future<void> reloadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await fetchHistory(user.uid);
    }
  }

  /// Manually add messages to current session (e.g. from voice consultation).
  void addMessages(List<ChatMessage> newMessages) {
    final current = state.value ?? [];
    final updated = [...current, ...newMessages];
    state = AsyncValue.data(updated);

    final userId = _currentUserId();
    _commitMessagesToSession(userId, updated);
  }

  void _commitMessagesToSession(String userId, List<ChatMessage> messages) {
    if (messages.isEmpty) return;

    final currentId = activeSessionId;
    final index = _sessions.indexWhere((s) => s.id == currentId);
    if (index >= 0) {
      // Update existing session
      final existing = _sessions[index];
      _sessions[index] = existing.copyWith(
        messages: messages,
        updatedAt: DateTime.now(),
      );
    } else {
      // Create new session
      final firstUser = messages.firstWhere(
        (m) => m.role == 'user',
        orElse: () => messages.first,
      );
      final newSession = ChatSession(
        id: currentId,
        title: _deriveTitle(firstUser.content),
        mode: _mode,
        createdAt: messages.first.timestamp,
        updatedAt: DateTime.now(),
        messages: messages,
      );
      _sessions.insert(0, newSession);
    }

    // Re-sort: newest first
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _saveSessions(userId);
    _touchActivity(userId);

    // Keep legacy cache up-to-date
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final listJson = messages.map((e) => e.toJson()).toList();
      prefs.setChatCache(userId, json.encode(listJson));
    } catch (_) {}
  }

  Future<void> fetchHistory(String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/assistant/history', queryParameters: {'limit': 50});
      final List<dynamic> messagesJson = response.data['messages'] ?? [];
      final messages = messagesJson.map((e) => ChatMessage.fromJson(e)).toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted && messages.isNotEmpty && (state.value == null || state.value!.isEmpty)) {
        // Only load if current session is empty
        state = AsyncValue.data(messages);
        _commitMessagesToSession(userId, messages);
      }
    } catch (e, stack) {
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> sendMessage(String text, String languageCode) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ??
        await _ref.read(secureStorageServiceProvider).getAuthToken();
    if (user == null && (token == null || token.isEmpty)) return;

    final currentMessages = state.value ?? [];

    // 1. Append user message and loading assistant message placeholder
    final attachedImageUrl = _medicationImageUrl;
    final userMsg = ChatMessage(role: 'user', content: text, imageUrl: attachedImageUrl, timestamp: DateTime.now());
    final assistantMsgPlaceholder = ChatMessage(role: 'assistant', content: '', timestamp: DateTime.now());

    state = AsyncValue.data([...currentMessages, userMsg, assistantMsgPlaceholder]);

    final int assistantIndex = state.value!.length - 1;
    String fullResponse = '';

    _ref.read(chatStreamingProvider.notifier).state = '';

    try {
      final request = http.Request('POST', Uri.parse('${ApiConstants.baseUrl}/assistant/chat/stream'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
      });

      final Map<String, dynamic> payload = {
        'message': text,
        'include_history': true,
        'language': languageCode,
        'mode': _mode,
      };
      if (_medicationContext != null && _medicationContext!.isNotEmpty) {
        payload['medication_context'] = _medicationContext;
        _medicationContext = null;
      }
      if (attachedImageUrl != null && attachedImageUrl.isNotEmpty) {
        payload['image_url'] = attachedImageUrl;
        _medicationImageUrl = null;
      }

      request.body = json.encode(payload);

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        if (response.statusCode == 402 || response.statusCode == 403) {
          throw InsufficientCreditsException('INSUFFICIENT_CREDITS');
        }
        throw Exception('Server error: ${response.statusCode}');
      }

      await response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6);
          try {
            final data = json.decode(dataStr);
            if (data['heartbeat'] == true) return;

            if (data['error'] != null) {
              if (data['error'] == 'INSUFFICIENT_CREDITS' || data['status'] == 402) {
                throw InsufficientCreditsException('INSUFFICIENT_CREDITS');
              }
              throw Exception(data['error']);
            }

            if (data['chunk'] != null) {
              fullResponse += data['chunk'] as String;
              _ref.read(chatStreamingProvider.notifier).state = fullResponse;
            }
          } catch (e) {
            if (e is InsufficientCreditsException) rethrow;
          }
        }
      });

      client.close();
      _ref.read(creditsProvider.notifier).fetchCredits(quietly: true);

      if (mounted) {
        final list = List<ChatMessage>.from(state.value!);
        list[assistantIndex] = ChatMessage(
          role: 'assistant',
          content: fullResponse,
          timestamp: list[assistantIndex].timestamp,
        );
        state = AsyncValue.data(list);

        final userId = _currentUserId();
        _commitMessagesToSession(userId, list);
      }

      _ref.read(chatStreamingProvider.notifier).state = '';
    } catch (e) {
      if (mounted) {
        final list = List<ChatMessage>.from(state.value!);
        if (list.length > assistantIndex) {
          list.removeAt(assistantIndex);
          state = AsyncValue.data(list);
        }
      }
      _ref.read(chatStreamingProvider.notifier).state = '';
      rethrow;
    }
  }
}

final chatStreamingProvider = StateProvider<String>((ref) => '');

final chatProvider = StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  return ChatNotifier(ref);
});

final chatSessionsProvider = Provider<List<ChatSession>>((ref) {
  ref.watch(chatProvider);
  return ref.read(chatProvider.notifier).sessions;
});

final activeChatSessionIdProvider = Provider<String>((ref) {
  ref.watch(chatProvider);
  return ref.read(chatProvider.notifier).activeSessionId;
});
