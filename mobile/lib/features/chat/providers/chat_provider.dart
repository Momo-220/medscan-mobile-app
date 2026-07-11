import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/remote/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/credits_provider.dart';

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Ref _ref;

  ChatNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _loadCacheAndFetchHistory(user.uid);
      } else {
        state = const AsyncValue.data([]);
      }
    }, fireImmediately: true);
  }

  void _loadCacheAndFetchHistory(String userId) {
    // 1. Try to load local cache first (offline support)
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final cacheJson = prefs.getChatCache(userId);
    if (cacheJson != null) {
      try {
        final List<dynamic> list = json.decode(cacheJson);
        final cachedMessages = list.map((e) => ChatMessage.fromJson(e)).toList();
        state = AsyncValue.data(cachedMessages);
      } catch (_) {}
    }

    // 2. Fetch fresh history from API
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
    if (user == null) return;

    final currentMessages = state.value ?? [];
    
    // 1. Append user message and loading assistant message placeholder
    final userMsg = ChatMessage(role: 'user', content: text, timestamp: DateTime.now());
    final assistantMsgPlaceholder = ChatMessage(role: 'assistant', content: '', timestamp: DateTime.now());

    state = AsyncValue.data([...currentMessages, userMsg, assistantMsgPlaceholder]);

    // Track active assistant index to update dynamically during streaming
    final int assistantIndex = state.value!.length - 1;
    String fullResponse = '';

    try {
      final token = await user.getIdToken() ?? await _ref.read(secureStorageServiceProvider).getAuthToken();
      
      final request = http.Request('POST', Uri.parse('${ApiConstants.baseUrl}/assistant/chat/stream'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
      });
      request.body = json.encode({
        'message': text,
        'include_history': true,
        'language': languageCode,
      });

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        if (response.statusCode == 402) {
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
            if (data['error'] != null) {
              if (data['error'] == 'INSUFFICIENT_CREDITS' || data['status'] == 402) {
                throw InsufficientCreditsException('INSUFFICIENT_CREDITS');
              }
              throw Exception(data['error']);
            }

            if (data['chunk'] != null) {
              fullResponse += data['chunk'] as String;
              
              // Update assistant message content in state in real-time
              if (mounted) {
                final list = List<ChatMessage>.from(state.value!);
                list[assistantIndex] = ChatMessage(
                  role: 'assistant',
                  content: fullResponse,
                  timestamp: list[assistantIndex].timestamp,
                );
                state = AsyncValue.data(list);
              }
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

      // Save cache locally
      if (mounted) {
        _saveCache(user.uid, state.value!);
      }
    } catch (e) {
      // Revert assistant message placeholder on error and show warning
      if (mounted) {
        final list = List<ChatMessage>.from(state.value!);
        list.removeAt(assistantIndex); // Remove placeholder
        state = AsyncValue.data(list);
      }
      rethrow;
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  return ChatNotifier(ref);
});
