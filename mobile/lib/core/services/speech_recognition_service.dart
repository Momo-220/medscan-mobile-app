import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Explicit application states for voice input & conversational UI
enum SpeechState {
  idle,
  requestingPermission,
  listening,
  detectingSpeech,
  silenceConfirmation,
  processing,
  responseReady,
  error,
}

/// Service abstraction for reliable on-device/native speech recognition.
/// Handles:
/// - iOS Speech framework & Android SpeechRecognizer native configuration
/// - 2-second silence confirmation window with resume/confirm actions
/// - Normalized real-time audio sound levels (0.0 to 1.0) without competing audio streams
/// - Circuit-breaker pattern to strictly prevent infinite restart loops (e.g. iOS Simulator error 300)
/// - Multi-language locale negotiation (French, English, Turkish)
/// - Deduplication of partial and final speech segments
class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();

  // State notifiers
  final ValueNotifier<SpeechState> stateNotifier = ValueNotifier(SpeechState.idle);
  final ValueNotifier<String> transcriptNotifier = ValueNotifier('');
  final ValueNotifier<double> soundLevelNotifier = ValueNotifier(0.0);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  // Silence detection
  Timer? _silenceTimer;
  final Duration silenceDuration;

  // Internal tracking
  String _confirmedPrefix = '';
  int _consecutiveErrorCount = 0;
  static const int _maxRetries = 2;
  bool _isDisposed = false;
  bool _isInitialized = false;

  SpeechRecognitionService({
    this.silenceDuration = const Duration(seconds: 10),
  });

  SpeechState get state => stateNotifier.value;
  String get transcript => transcriptNotifier.value;
  double get soundLevel => soundLevelNotifier.value;
  String? get errorMessage => errorNotifier.value;
  bool get isListening => _speechToText.isListening;

  /// Check permissions and initialize native speech recognition engine
  Future<bool> initialize() async {
    if (_isDisposed) return false;

    _setState(SpeechState.requestingPermission);

    try {
      // 1. Microphone permission check via permission_handler
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final requestResult = await Permission.microphone.request();
        if (!requestResult.isGranted) {
          _setError('Permission microphone refusée. Veuillez l\'activer dans les réglages.');
          return false;
        }
      }

      // 2. Speech recognition permission check for iOS
      if (Platform.isIOS) {
        final speechStatus = await Permission.speech.status;
        if (!speechStatus.isGranted) {
          final speechReq = await Permission.speech.request();
          if (!speechReq.isGranted) {
            _setError('Permission de reconnaissance vocale refusée.');
            return false;
          }
        }
      }

      // 3. Initialize SpeechToText engine with explicit callbacks
      final available = await _speechToText.initialize(
        onError: _handleNativeError,
        onStatus: _handleNativeStatus,
        debugLogging: kDebugMode,
      );

      _isInitialized = available;

      if (!available) {
        _setError('Service de reconnaissance vocale indisponible sur cet appareil.');
        return false;
      }

      _setState(SpeechState.idle);
      return true;
    } catch (e) {
      debugPrint('[SpeechRecognitionService] Initialization exception: $e');
      _setError('Erreur lors de l\'initialisation de la reconnaissance vocale.');
      return false;
    }
  }

  /// Start listening with specific language locale
  Future<void> startListening({
    required String languageCode,
    bool append = false,
  }) async {
    if (_isDisposed) return;

    if (!append) {
      _confirmedPrefix = '';
      transcriptNotifier.value = '';
    }

    _cancelSilenceTimer();

    if (!_isInitialized || !_speechToText.isAvailable) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    // Stop current recognition cleanly before re-arming
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    final localeId = _resolveLocaleId(languageCode);

    _setState(SpeechState.listening);
    errorNotifier.value = null;

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: _handleSoundLevelChange,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('[SpeechRecognitionService] Listen start error: $e');
      _handleNativeError(SpeechRecognitionError('listen_failed', true));
    }
  }

  /// Handle incoming partial and final results from speech recognizer
  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (_isDisposed) return;

    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    final combined = _confirmedPrefix.isNotEmpty
        ? '$_confirmedPrefix $words'.trim()
        : words;

    transcriptNotifier.value = combined;
    _consecutiveErrorCount = 0; // Reset error counter on valid speech

    if (state != SpeechState.detectingSpeech) {
      _setState(SpeechState.detectingSpeech);
    }

    // Reset silence timer on every new speech event
    _restartSilenceTimer();
  }

  /// Normalize native audio level to 0.0 - 1.0 range
  void _handleSoundLevelChange(double level) {
    if (_isDisposed) return;
    // On iOS level is typically -10 to 10 dB, on Android 0 to 100
    double normalized = 0.0;
    if (Platform.isIOS) {
      normalized = ((level + 10.0) / 20.0).clamp(0.0, 1.0);
    } else {
      normalized = (level / 100.0).clamp(0.0, 1.0);
    }
    soundLevelNotifier.value = normalized;
  }

  /// 2-second silence timer handler
  void _restartSilenceTimer() {
    _cancelSilenceTimer();
    _silenceTimer = Timer(silenceDuration, () {
      if (_isDisposed) return;
      if (state == SpeechState.detectingSpeech && transcript.trim().isNotEmpty) {
        _onSilenceDetected();
      }
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// Triggered after 10 seconds of silence
  Future<void> _onSilenceDetected() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    _setState(SpeechState.silenceConfirmation);
    HapticFeedback.lightImpact();
  }

  /// User action: Resume speaking (dismiss confirmation, keep previous transcription)
  Future<void> resumeSpeaking({required String languageCode}) async {
    if (_isDisposed) return;
    _cancelSilenceTimer();

    // Preserve the current transcript as confirmed prefix so subsequent speech appends
    if (transcript.trim().isNotEmpty) {
      _confirmedPrefix = transcript.trim();
    }

    await startListening(languageCode: languageCode, append: true);
  }

  /// User action: Confirm finish (or manual finish)
  Future<String> confirmFinish() async {
    _cancelSilenceTimer();
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    _setState(SpeechState.processing);
    return transcript.trim();
  }

  /// User action: Manual finish button pressed during active listening
  Future<String> manualFinish() async {
    return await confirmFinish();
  }

  /// User action: Cancel and reset
  Future<void> cancel() async {
    _cancelSilenceTimer();
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (_) {}
    _confirmedPrefix = '';
    transcriptNotifier.value = '';
    soundLevelNotifier.value = 0.0;
    _setState(SpeechState.idle);
  }

  /// Internal handler for native engine status changes
  void _handleNativeStatus(String status) {
    debugPrint('[SpeechRecognitionService] Native status: $status');
    if (_isDisposed) return;

    if (status == 'notListening' || status == 'done') {
      soundLevelNotifier.value = 0.0;
      // Do NOT trigger an auto-restart loop if recognition completed or timed out
      if (state == SpeechState.listening && transcript.trim().isEmpty) {
        _setState(SpeechState.idle);
      }
    }
  }

  /// Internal handler for native engine errors
  void _handleNativeError(SpeechRecognitionError error) {
    debugPrint('[SpeechRecognitionService] Native error: ${error.errorMsg} (permanent: ${error.permanent})');
    if (_isDisposed) return;

    _cancelSilenceTimer();
    soundLevelNotifier.value = 0.0;
    _consecutiveErrorCount++;

    final errorMsg = error.errorMsg.toLowerCase();

    // Detect iOS error 300 / Simulator / Dictation unavailable
    if (errorMsg.contains('300') ||
        errorMsg.contains('error_unknown') ||
        errorMsg.contains('error_speech_timeout') && Platform.isIOS && !kReleaseMode) {
      // Clear explanation for iOS Simulator limitation
      _setError(
        'La reconnaissance vocale native Apple nécessite un appareil physique avec micro configuré (non supporté sur simulateur). Vous pouvez utiliser le clavier ci-dessous.',
      );
      return;
    }

    if (errorMsg.contains('error_no_match') || errorMsg.contains('no speech')) {
      if (transcript.isNotEmpty) {
        _setState(SpeechState.silenceConfirmation);
      } else {
        _setState(SpeechState.idle);
      }
      return;
    }

    if (errorMsg.contains('permission')) {
      _setError('Permission d\'enregistrement vocal refusée.');
      return;
    }

    if (_consecutiveErrorCount >= _maxRetries) {
      _setError('Échec de la reconnaissance vocale (${error.errorMsg}). Veuillez réessayer.');
    } else {
      _setState(SpeechState.idle);
    }
  }

  /// Maps language codes to platform locale identifiers
  String _resolveLocaleId(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'fr':
        return 'fr_FR';
      case 'tr':
        return 'tr_TR';
      case 'en':
      default:
        return 'en_US';
    }
  }

  void _setState(SpeechState newState) {
    if (_isDisposed) return;
    if (stateNotifier.value != newState) {
      stateNotifier.value = newState;
    }
  }

  void _setError(String message) {
    if (_isDisposed) return;
    errorNotifier.value = message;
    stateNotifier.value = SpeechState.error;
  }

  /// Clean up all timers and native resources
  void dispose() {
    _isDisposed = true;
    _cancelSilenceTimer();
    try {
      _speechToText.stop();
    } catch (_) {}
    stateNotifier.dispose();
    transcriptNotifier.dispose();
    soundLevelNotifier.dispose();
    errorNotifier.dispose();
  }
}
