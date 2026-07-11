import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/credits.dart';
import '../../../data/remote/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/di/providers.dart';

class CreditsNotifier extends StateNotifier<AsyncValue<Credits>> {
  final Ref _ref;
  final _client;
  final _storage;
  final _prefs;
  Timer? _timer;

  CreditsNotifier(this._ref)
      : _client = _ref.read(apiClientProvider),
        _storage = _ref.read(secureStorageServiceProvider),
        _prefs = _ref.read(sharedPrefsServiceProvider),
        super(const AsyncValue.loading()) {
    // Listen to authentication state to start or stop polling
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      _syncCreditsState();
    }, fireImmediately: true);
  }

  void _syncCreditsState() async {
    final user = _ref.read(firebaseAuthStateProvider).value;
    final token = await _storage.getAuthToken();
    
    if (user != null || (token != null && token.isNotEmpty)) {
      // Load cached value instantly to avoid delay
      final cachedCredits = _prefs.getCreditsCache(user?.uid ?? 'trial');
      if (cachedCredits != null) {
        state = AsyncValue.data(Credits(credits: cachedCredits));
      } else {
        state = const AsyncValue.loading();
      }

      fetchCredits(quietly: cachedCredits != null);
      _startTimer();
    } else {
      _stopTimer();
      state = AsyncValue.data(Credits(credits: 0));
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => fetchCredits(quietly: true));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchCredits({bool quietly = false}) async {
    final token = await _storage.getAuthToken();
    if (token == null || token.isEmpty) {
      if (!quietly) {
        state = AsyncValue.data(Credits(credits: 0));
      }
      return;
    }

    if (!quietly) {
      state = const AsyncValue.loading();
    }

    try {
      final response = await _client.get('/credits');
      final credits = Credits.fromJson(response.data);
      
      // Save to cache
      final user = _ref.read(firebaseAuthStateProvider).value;
      await _prefs.setCreditsCache(user?.uid ?? 'trial', credits.credits);

      if (mounted) {
        state = AsyncValue.data(credits);
      }
    } catch (e, stack) {
      if (mounted && !quietly) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  // Admin function to add credits (matches addCredits in CreditsContext)
  Future<void> addCredits(int amount) async {
    try {
      final response = await _client.post('/credits/add', data: {'amount': amount});
      final credits = Credits.fromJson(response.data);
      
      final user = _ref.read(firebaseAuthStateProvider).value;
      await _prefs.setCreditsCache(user?.uid ?? 'trial', credits.credits);

      state = AsyncValue.data(credits);
    } catch (e) {
      debugPrint('Error adding credits: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

// Credits Provider
final creditsProvider = StateNotifierProvider<CreditsNotifier, AsyncValue<Credits>>((ref) {
  return CreditsNotifier(ref);
});
