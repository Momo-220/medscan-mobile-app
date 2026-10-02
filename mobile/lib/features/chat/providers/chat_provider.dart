import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/chat_message.dart';
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

  ChatNotifier(this._ref) : super(_getInitialMessages(_ref)) {
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _loadCacheAndFetchHistory(user.uid);
      } else {
        state = const AsyncValue.data([]);
      }
    }, fireImmediately: true);
  }

  static AsyncValue<List<ChatMessage>> _getInitialMessages(Ref ref) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final cacheKey = user?.uid ?? 'trial';
      final prefs = ref.read(sharedPrefsServiceProvider);
      final cacheJson = prefs.getChatCache(cacheKey);
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final List<dynamic> list = json.decode(cacheJson);
        final cachedMessages = list.map((e) => ChatMessage.fromJson(e)).toList();
        return AsyncValue.data(cachedMessages);
      }
    } catch (_) {}
    return const AsyncValue.data([]);
  }

  /// Switch between 'chat' and 'consultation' modes.
  /// Clears current conversation so each mode starts fresh.
  void setMode(String newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    _medicationContext = null; // reset scan context on mode switch
    _medicationImageUrl = null;
    // Clear messages for a fresh session in the new mode
    state = const AsyncValue.data([]);
  }

  /// Inject a medication name as context (scan-to-chat feature).
  void setMedicationContext(String? name, {String? imageUrl}) {
    _medicationContext = name;
    _medicationImageUrl = imageUrl;
  }

  /// Clear the current conversation (new conversation button).
  void clearHistory() {
    state = const AsyncValue.data([]);
    _medicationContext = null;
    _medicationImageUrl = null;
    // Clear streaming state
    _ref.read(chatStreamingProvider.notifier).state = '';
    // Clear cache for the current user or trial session
    final user = FirebaseAuth.instance.currentUser;
    final cacheKey = user?.uid ?? 'trial';
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      prefs.setChatCache(cacheKey, '[]');
    } catch (_) {}
  }

  /// Explicitly reload history from backend.
  Future<void> reloadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await fetchHistory(user.uid);
    }
  }

  void _loadCacheAndFetchHistory(String userId) {
    // 1. Try to load local cache first (instantaneous, offline support)
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final cacheJson = prefs.getChatCache(userId);
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final List<dynamic> list = json.decode(cacheJson);
        final cachedMessages = list.map((e) => ChatMessage.fromJson(e)).toList();
        state = AsyncValue.data(cachedMessages);
      } else if (state.value == null) {
        state = const AsyncValue.data([]);
      }
    } catch (_) {
      if (state.value == null) {
        state = const AsyncValue.data([]);
      }
    }

    // 2. Fetch fresh history from API in background without blocking UI
    fetchHistory(userId);
  }

  Future<void> fetchHistory(String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.isAnonymous) {
      // Anonymous users don't have persistent backend history.
      // We rely on local device cache.
      if (state.value == null) {
        state = const AsyncValue.data([]);
      }
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/assistant/history', queryParameters: {'limit': 50});
      
      final List<dynamic> messagesJson = response.data['messages'] ?? [];
      final messages = messagesJson.map((e) => ChatMessage.fromJson(e)).toList();
      
      // Order messages by ascending timestamp (oldest first for chat display)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        state = AsyncValue.data(messages);
        _saveCache(userId, messages);
      }
    } catch (e, stack) {
      // If we already have cached data, don't show full screen error
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  void _saveCache(String userId, List<ChatMessage> messages) {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final listJson = messages.map((e) => e.toJson()).toList();
      prefs.setChatCache(userId, json.encode(listJson));
    } catch (_) {}
  }

  Future<void> sendMessage(String text, String languageCode) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ??
        await _ref.read(secureStorageServiceProvider).getAuthToken();
    if (user == null && (token == null || token.isEmpty)) return;

    final currentMessages = state.value ?? [];
    
    // 1. Append user message and loading assistant message placeholder
    // Attach medication image if available (scan-to-chat feature)
    final attachedImageUrl = _medicationImageUrl;
    final userMsg = ChatMessage(role: 'user', content: text, imageUrl: attachedImageUrl, timestamp: DateTime.now());
    final assistantMsgPlaceholder = ChatMessage(role: 'assistant', content: '', timestamp: DateTime.now());

    state = AsyncValue.data([...currentMessages, userMsg, assistantMsgPlaceholder]);

    // Track active assistant index to update dynamically
    final int assistantIndex = state.value!.length - 1;
    String fullResponse = '';

    // Initialize the streaming state
    _ref.read(chatStreamingProvider.notifier).state = '';

    try {
      final request = http.Request('POST', Uri.parse('${ApiConstants.baseUrl}/assistant/chat/stream'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
      });

      // Build payload with mode and optional medication context
      final Map<String, dynamic> payload = {
        'message': text,
        'include_history': true,
        'language': languageCode,
        'mode': _mode,
      };
      if (_medicationContext != null && _medicationContext!.isNotEmpty) {
        payload['medication_context'] = _medicationContext;
        // Only send context once (for the first message)
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

      // Read lines from SSE byte stream
      await response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6);
          try {
            final data = json.decode(dataStr);

            // Skip heartbeat packets silently
            if (data['heartbeat'] == true) return;

            if (data['error'] != null) {
              if (data['error'] == 'INSUFFICIENT_CREDITS' || data['status'] == 402) {
                throw InsufficientCreditsException('INSUFFICIENT_CREDITS');
              }
              throw Exception(data['error']);
            }

            if (data['chunk'] != null) {
              fullResponse += data['chunk'] as String;
              
              // Only update the stream provider to trigger local rebuilds, no general state rebuild
              _ref.read(chatStreamingProvider.notifier).state = fullResponse;
            }
          } catch (e) {
            if (e is InsufficientCreditsException) rethrow;
          }
        }
      });

      // Cleanup client connection
      client.close();

      // Refresh credits balance provider
      _ref.read(creditsProvider.notifier).fetchCredits(quietly: true);

      // Once generation is finished, commit final response to general persistent state
      if (mounted) {
        final list = List<ChatMessage>.from(state.value!);
        list[assistantIndex] = ChatMessage(
          role: 'assistant',
          content: fullResponse,
          timestamp: list[assistantIndex].timestamp,
        );
        state = AsyncValue.data(list);
        final cacheKey = user?.uid ?? 'trial';
        _saveCache(cacheKey, list);
      }
      
      // Clear streaming state
      _ref.read(chatStreamingProvider.notifier).state = '';
    } catch (e) {
      // Revert assistant message placeholder on error and clear streaming state
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
