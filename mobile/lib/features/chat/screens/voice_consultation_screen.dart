import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/services/speech_recognition_service.dart';
import '../../../../data/models/chat_message.dart';
import '../../../../data/models/recent_scan.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/medication_recommendation_card.dart';
import '../../history/providers/pharmacy_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/doctor_provider.dart';

/// Screen launched when tapping the microphone button in consultation chat.
/// Features:
/// 1. Reliable native Speech Recognition architecture (iOS Speech framework / Android SpeechRecognizer).
/// 2. Reactive sphere animation modulated by real native audio sound levels.
/// 3. 10-second silence confirmation ("Avez-vous terminé ?" with "Terminer" and "Continuer à parler").
/// 4. Circuit-breaker preventing infinite restart loops on iOS simulator or device errors.
/// 5. Text-only AI response with song lyrics / karaoke typing (zero TTS / audio playback).
/// 6. Immediate manual finish button and multi-language support (French, English, Turkish).
class VoiceConsultationScreen extends ConsumerStatefulWidget {
  final String? mode;

  const VoiceConsultationScreen({
    super.key,
    this.mode,
  });

  @override
  ConsumerState<VoiceConsultationScreen> createState() => _VoiceConsultationScreenState();
}

class _VoiceConsultationScreenState extends ConsumerState<VoiceConsultationScreen>
    with TickerProviderStateMixin {
  String get activeMode => widget.mode ?? ref.read(chatProvider.notifier).mode;
  bool get isConsultation => activeMode == 'consultation';

  // Service abstraction for speech recognition (10-second silence detection)
  final SpeechRecognitionService _speechService = SpeechRecognitionService(
    silenceDuration: const Duration(seconds: 10),
  );

  // Sphere pulse and shrinking animation
  late AnimationController _spherePulseController;
  late AnimationController _sphereShrinkController;
  late Animation<double> _sphereSizeAnimation;
  late Animation<double> _sphereVerticalOffsetAnimation;

  // Cursor blink animation
  late AnimationController _cursorBlinkController;

  // Doctor response lyrics typing engine
  List<String> _doctorSentences = [];
  int _currentSentenceIndex = 0;
  String _displayedCurrentSentence = '';
  int _charIndex = 0;
  Timer? _typingTimer;
  Timer? _autoResumeTimer;
  String _lastFullDoctorText = '';
  String _lastUserQuery = '';
  bool _hasCommittedCurrentTurn = false;

  // Scroll controller for the song lyrics view
  final ScrollController _lyricsScrollController = ScrollController();

  // Submission guard
  bool _isSubmitting = false;

  // Active medication recommendation from personal pharmacy
  Map<String, dynamic>? _recommendedMedication;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mode != null && widget.mode != ref.read(chatProvider.notifier).mode) {
        ref.read(chatProvider.notifier).setMode(widget.mode!);
      }
    });

    // Pulse animation for the sphere while idle/listening
    _spherePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Smooth upward shrinking animation for the sphere when doctor answers
    _sphereShrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _sphereSizeAnimation = Tween<double>(
      begin: 260.0,
      end: 105.0,
    ).animate(CurvedAnimation(
      parent: _sphereShrinkController,
      curve: Curves.easeInOutCubic,
    ));

    _sphereVerticalOffsetAnimation = Tween<double>(
      begin: 10.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _sphereShrinkController,
      curve: Curves.easeInOutCubic,
    ));

    // Cursor blink animation
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Wire speech recognition state transitions
    _speechService.stateNotifier.addListener(_onSpeechStateChanged);

    // Initialize and start voice capture after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndStartVoice();
    });
  }

  void _onSpeechStateChanged() {
    if (!mounted) return;
    final state = _speechService.state;

    if (state == SpeechState.processing) {
      if (_sphereShrinkController.value < 0.9) {
        _sphereShrinkController.forward();
      }
    } else if (state == SpeechState.listening || state == SpeechState.detectingSpeech) {
      if (_sphereShrinkController.value > 0.1) {
        _sphereShrinkController.reverse();
      }
    }
    setState(() {});
  }

  Future<void> _initAndStartVoice() async {
    final lang = ref.read(languageProvider);
    final available = await _speechService.initialize();
    if (available && mounted) {
      await _speechService.startListening(languageCode: lang);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _autoResumeTimer?.cancel();
    _speechService.stateNotifier.removeListener(_onSpeechStateChanged);
    _speechService.dispose();
    _spherePulseController.dispose();
    _sphereShrinkController.dispose();
    _cursorBlinkController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  // ── User Actions ───────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    HapticFeedback.mediumImpact();
    _autoResumeTimer?.cancel();

    // If doctor is replying or has replied, tapping mic resumes conversation immediately
    if (_speechService.state == SpeechState.responseReady) {
      _typingTimer?.cancel();
      if (!_hasCommittedCurrentTurn && _lastFullDoctorText.isNotEmpty) {
        _hasCommittedCurrentTurn = true;
        _onAllLyricsFinished(_lastFullDoctorText, _lastUserQuery);
      }
      _sphereShrinkController.reverse();
      final lang = ref.read(languageProvider);
      await _speechService.startListening(languageCode: lang);
      return;
    }

    if (_speechService.state == SpeechState.silenceConfirmation) {
      await _onConfirmFinish();
      return;
    }

    if (_speechService.isListening) {
      final text = _speechService.transcript.trim();
      if (text.isNotEmpty) {
        await _onConfirmFinish();
      } else {
        await _speechService.cancel();
      }
      return;
    }

    final lang = ref.read(languageProvider);
    await _speechService.startListening(languageCode: lang);
  }

  Future<void> _onConfirmFinish() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    HapticFeedback.mediumImpact();

    final queryText = await _speechService.confirmFinish();
    if (queryText.isEmpty) {
      _isSubmitting = false;
      return;
    }

    await _submitUserQuery(queryText);
    _isSubmitting = false;
  }

  Future<void> _onResumeSpeaking() async {
    HapticFeedback.lightImpact();
    final lang = ref.read(languageProvider);
    await _speechService.resumeSpeaking(languageCode: lang);
  }

  void _toggleLanguage() {
    HapticFeedback.selectionClick();
    final current = ref.read(languageProvider);
    // Cycle: fr -> en -> tr -> fr
    String next = 'en';
    if (current == 'fr') {
      next = 'en';
    } else if (current == 'en') {
      next = 'tr';
    } else {
      next = 'fr';
    }

    ref.read(languageProvider.notifier).setLanguage(next);

    // If currently listening, re-arm with the new locale
    if (_speechService.isListening) {
      _speechService.startListening(languageCode: next, append: true);
    }
  }

  // ── AI Submission & Progressive Text-Only Lyrics Animation ─────────────────

  Future<void> _submitUserQuery(String queryText) async {
    final lang = ref.read(languageProvider);

    // Sphere shrinks upwards smoothly
    _sphereShrinkController.forward();

    String doctorReply = '';
    Map<String, dynamic>? recommendedMed;

    try {
      final pharmacy = ref.read(pharmacyProvider);
      final List<Map<String, dynamic>> localScans = pharmacy.allScans.take(25).map((s) => {
        'scan_id': s.scanId,
        'id': s.id,
        'medication_name': s.medicationName,
        'dosage': s.dosage,
        'form': s.form,
        'category': s.category,
        'image_url': s.imageUrl,
        'indications': s.analysisData?['indications'] ?? '',
        'contraindications': s.contraindications,
      }).toList();

      final medCtx = ref.read(chatProvider.notifier).medicationContext;

      final client = ref.read(apiClientProvider);
      final response = await client.post(
        '/assistant/chat',
        data: {
          'message': queryText,
          'language': lang,
          'mode': activeMode,
          'include_history': false,
          if (medCtx != null && medCtx.isNotEmpty) 'medication_context': medCtx,
          if (localScans.isNotEmpty) 'local_scans': localScans,
        },
      );

      final msg = response.data['message'];
      if (msg is String && msg.trim().isNotEmpty) {
        doctorReply = msg.trim();
      }

      final rec = response.data['recommended_medication'] ?? MedicationRecommendationParser.parse(doctorReply);
      if (rec is Map<String, dynamic>) {
        recommendedMed = rec;
      }
    } catch (_) {
      doctorReply = _getFallbackReply(queryText, lang);
    }

    if (doctorReply.isEmpty) {
      doctorReply = _getFallbackReply(queryText, lang);
    }

    if (recommendedMed == null && !isConsultation) {
      final pharmacy = ref.read(pharmacyProvider);
      final q = queryText.toLowerCase();
      RecentScan? matchingScan;
      try {
        matchingScan = pharmacy.allScans.firstWhere(
          (s) {
            final n = s.medicationName.toLowerCase();
            final ind = (s.analysisData?['indications'] ?? '').toString().toLowerCase();
            return q.contains(n) ||
                (q.contains('tête') && (n.contains('doliprane') || n.contains('paracétamol') || n.contains('paracetamol') || n.contains('ibuprof') || ind.contains('douleur') || ind.contains('céphalée') || ind.contains('tête'))) ||
                (q.contains('estomac') && (n.contains('gaviscon') || n.contains('pantoprazole') || n.contains('oméprazole') || ind.contains('estomac') || ind.contains('brûlure')));
          },
        );
      } catch (_) {
        matchingScan = null;
      }
      if (matchingScan != null) {
        recommendedMed = {
          'id': matchingScan.scanId.isNotEmpty ? matchingScan.scanId : matchingScan.id,
          'scan_id': matchingScan.scanId.isNotEmpty ? matchingScan.scanId : matchingScan.id,
          'medication_name': matchingScan.medicationName,
          'dosage': matchingScan.dosage ?? '',
          'form': matchingScan.form ?? '',
          'category': matchingScan.category,
          'image_url': matchingScan.imageUrl,
        };
      }
    }

    if (mounted) {
      setState(() {
        _recommendedMedication = recommendedMed;
      });
      _startLyricsSongAnimation(doctorReply, queryText);
    }
  }

  List<String> _splitIntoLyrics(String text) {
    // Splits text cleanly by sentences for karaoke / lyrics progression
    // Strips markdown characters and tags so text looks clean and editorial
    final stripped = MedicationRecommendationParser.cleanText(text);
    final clean = stripped
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('###', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('\n', ' ')
        .trim();
    final rawParts = clean.split(RegExp(r'(?<=[.!?])\s+'));
    final List<String> result = [];

    for (final p in rawParts) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty) {
        if (trimmed.length > 90) {
          final words = trimmed.split(' ');
          final half = (words.length / 2).round();
          result.add(words.sublist(0, half).join(' '));
          result.add(words.sublist(half).join(' '));
        } else {
          result.add(trimmed);
        }
      }
    }
    return result.isNotEmpty ? result : [text];
  }

  void _startLyricsSongAnimation(String fullDoctorText, String userQuery) {
    _typingTimer?.cancel();
    final sentences = _splitIntoLyrics(fullDoctorText);

    setState(() {
      _lastFullDoctorText = fullDoctorText;
      _lastUserQuery = userQuery;
      _hasCommittedCurrentTurn = false;
      _doctorSentences = sentences;
      _currentSentenceIndex = 0;
      _displayedCurrentSentence = '';
      _charIndex = 0;
    });

    _speechService.stateNotifier.value = SpeechState.responseReady;
    _typeCurrentLyricSentence(fullDoctorText, userQuery);
  }

  void _typeCurrentLyricSentence(String fullDoctorText, String userQuery) {
    if (_currentSentenceIndex >= _doctorSentences.length) {
      _onAllLyricsFinished(fullDoctorText, userQuery);
      return;
    }

    final targetSentence = _doctorSentences[_currentSentenceIndex];
    _charIndex = 0;
    _displayedCurrentSentence = '';

    _typingTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_charIndex < targetSentence.length) {
        setState(() {
          _charIndex++;
          _displayedCurrentSentence = targetSentence.substring(0, _charIndex);
        });
        _autoScrollLyrics();
      } else {
        timer.cancel();
        // Pause between lyric lines (400ms)
        Timer(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _currentSentenceIndex++;
            });
            _typeCurrentLyricSentence(fullDoctorText, userQuery);
          }
        });
      }
    });
  }

  void _onAllLyricsFinished(String fullDoctorText, String userQuery) {
    if (_hasCommittedCurrentTurn) return;
    _hasCommittedCurrentTurn = true;
    // Append conversation messages to chat history without audio playback
    try {
      final userMsg = ChatMessage(
        role: 'user',
        content: userQuery,
        timestamp: DateTime.now().subtract(const Duration(seconds: 4)),
      );
      final doctorMsg = ChatMessage(
        role: 'assistant',
        content: fullDoctorText,
        timestamp: DateTime.now(),
      );
      ref.read(chatProvider.notifier).addMessages([userMsg, doctorMsg]);
    } catch (_) {}

    // Auto-relance du microphone pour que l'utilisateur puisse répondre directement
    _autoResumeTimer?.cancel();
    _autoResumeTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      if (!_speechService.isListening &&
          _speechService.state != SpeechState.error &&
          _speechService.state != SpeechState.requestingPermission) {
        _sphereShrinkController.reverse();
        final lang = ref.read(languageProvider);
        await _speechService.startListening(languageCode: lang);
      }
    });
  }

  void _autoScrollLyrics() {
    if (_lyricsScrollController.hasClients) {
      _lyricsScrollController.animateTo(
        _lyricsScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _fastForwardLyrics() {
    _typingTimer?.cancel();
    setState(() {
      _currentSentenceIndex = _doctorSentences.length;
      _displayedCurrentSentence = '';
    });
    if (!_hasCommittedCurrentTurn && _lastFullDoctorText.isNotEmpty) {
      _onAllLyricsFinished(_lastFullDoctorText, _lastUserQuery);
    }
  }

  String _getFallbackReply(String query, String lang) {
    if (isConsultation) {
      return _getClinicalFallback(query, lang);
    }
    return _getChatFallback(query, lang);
  }

  String _getChatFallback(String query, String lang) {
    final q = query.toLowerCase();
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';

    final pharmacy = ref.read(pharmacyProvider);
    final headacheMeds = pharmacy.allScans.where((s) {
      final name = s.medicationName.toLowerCase();
      final ind = (s.analysisData?['indications'] ?? '').toString().toLowerCase();
      return name.contains('doliprane') ||
          name.contains('paracétamol') ||
          name.contains('paracetamol') ||
          name.contains('ibuprof') ||
          name.contains('aspirin') ||
          name.contains('advil') ||
          name.contains('dafalgan') ||
          name.contains('efferalgan') ||
          ind.contains('douleur') ||
          ind.contains('céphalée') ||
          ind.contains('tête') ||
          ind.contains('pain') ||
          ind.contains('headache');
    }).toList();

    if (headacheMeds.isNotEmpty && (q.contains('tête') || q.contains('mal') || q.contains('migraine') || q.contains('douleur') || q.contains('headache') || q.contains('pain'))) {
      final med = headacheMeds.first;
      final dosageStr = (med.dosage != null && med.dosage!.isNotEmpty) ? ' (${med.dosage})' : '';
      if (isFrench) {
        return 'Dans votre pharmacie, vous disposez de ${med.medicationName}$dosageStr. C\'est adapté pour soulager les maux de tête en respectant un intervalle de 4 à 6 heures entre les prises.';
      } else if (isTurkish) {
        return 'İlaç dolabınızda ${med.medicationName}$dosageStr bulunmaktadır. Baş ağrısını dindirmek için uygundur.';
      } else {
        return 'In your medicine cabinet, you have ${med.medicationName}$dosageStr, which is suitable for headaches with 4 to 6 hours between doses.';
      }
    }

    if (isFrench) {
      if (q.contains('tête') || q.contains('migraine') || q.contains('mal')) {
        return 'Pour soulager un mal de tête, le paracétamol est généralement recommandé en première intention (1g par prise, espacé de 4 à 6 heures, max 3g/jour). Hydratez-vous bien et reposez-vous.';
      } else if (q.contains('estomac') || q.contains('ventre') || q.contains('brûlure')) {
        return 'Pour les brûlures d\'estomac, un antiacide ou protecteur gastrique peut aider. Évitez les repas trop gras, le café et les anti-inflammatoires.';
      }
      return 'J\'ai bien noté votre demande. Veillez à toujours respecter la posologie indiquée sur vos boîtes de médicaments et demandez conseil à votre pharmacien.';
    } else if (isTurkish) {
      if (q.contains('baş') || q.contains('ağrı')) {
        return 'Baş ağrısı için parasetamol genellikle ilk seçenek olarak önerilir. Bol su için ve dinlenin.';
      }
      return 'Sorunuzu kaydettim. İlaçlarınızı her zaman kutudaki talimatlara uygun şekilde kullanınız.';
    } else {
      if (q.contains('headache') || q.contains('migraine') || q.contains('pain')) {
        return 'For headaches, paracetamol is generally recommended first-line (spaced 4 to 6 hours apart). Stay hydrated and rest in a quiet space.';
      }
      return 'I have noted your pharmaceutical question. Always follow the dosage instructions on your packaging.';
    }
  }

  String _getClinicalFallback(String query, String lang) {
    final q = query.toLowerCase();
    if (lang == 'fr') {
      if (q.contains('tête') || q.contains('migraine')) {
        return 'Je note vos maux de tête. Depuis combien de temps durent-ils et avez-vous une gêne à la lumière ? Pensez à bien vous hydrater et restez dans une pièce calme.';
      } else if (q.contains('paracétamol') || q.contains('ibuprofène') || q.contains('associer')) {
        return 'L\'association paracétamol et ibuprofène peut être envisagée en alternance sur avis médical, en respectant un intervalle d\'au moins 4 à 6 heures.';
      } else if (q.contains('estomac') || q.contains('ventre') || q.contains('douleur')) {
        return 'Pour vos douleurs abdominales, évitez l\'automédication par anti-inflammatoires à jeun et consultez rapidement si les douleurs persistent.';
      }
      return 'J\'ai bien enregistré votre question médicale. Pouvez-vous préciser l\'intensité des symptômes sur une échelle de 1 à 10 ?';
    } else if (lang == 'tr') {
      if (q.contains('baş') || q.contains('ağrı')) {
        return 'Baş ağrınızı kaydettim. Ne kadar süredir devam ediyor ve ışığa karşı hassasiyet var mı? Bol su içmeyi ve dinlenmeyi unutmayın.';
      }
      return 'Belirttiğiniz semptomları kaydettim. Şikayetlerinizin süresini ve şiddetini belirtebilir misiniz?';
    } else {
      if (q.contains('headache') || q.contains('migraine')) {
        return 'I have recorded your headaches. How long have they lasted and do you have sensitivity to light? Stay hydrated and rest in a quiet space.';
      } else if (q.contains('paracetamol') || q.contains('ibuprofen')) {
        return 'Alternating paracetamol and ibuprofen may be considered under medical advice, respecting a 4 to 6 hour interval.';
      }
      return 'I have recorded your clinical question. Could you specify the duration and intensity of these symptoms?';
    }
  }

  // ── Keyboard Fallback Modal ────────────────────────────────────────────────

  void _openKeyboardModal(bool isDark, String lang) {
    HapticFeedback.lightImpact();
    final textController = TextEditingController();
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isConsultation
                      ? (isFrench
                          ? 'Écrire vos symptômes'
                          : (isTurkish ? 'Belirtilerinizi yazın' : 'Type your symptoms'))
                      : (isFrench
                          ? 'Poser votre question'
                          : (isTurkish ? 'Sorunuzu yazın' : 'Ask your question')),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: isConsultation
                        ? (isFrench
                            ? 'Décrivez vos symptômes ou votre question...'
                            : (isTurkish ? 'Semptomlarınızı veya sorunuzu açıklayın...' : 'Describe your symptoms or question...'))
                        : (isFrench
                            ? 'Demandez un conseil, un médicament...'
                            : (isTurkish ? 'Bir ilaç veya tavsiye sorun...' : 'Ask about a medicine, dosage...')),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final text = textController.text.trim();
                          Navigator.pop(ctx);
                          context.pop(text);
                        },
                        child: Text(
                          isFrench ? 'Aller au chat' : (isTurkish ? 'Sohbete git' : 'Open in chat'),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final text = textController.text.trim();
                          Navigator.pop(ctx);
                          if (text.isNotEmpty) {
                            _submitUserQuery(text);
                          }
                        },
                        child: Text(
                          isConsultation
                              ? (isFrench ? 'Consulter' : (isTurkish ? 'Danış' : 'Consult'))
                              : (isFrench ? 'Envoyer' : (isTurkish ? 'Gönder' : 'Send')),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Main Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: bgColor,
          child: SafeArea(
            child: Column(
              children: [
                // ── Top Header Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back / Close Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _speechService.cancel();
                          context.pop();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 18,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),

                      // Doctor Info Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (isConsultation
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB))
                                .withValues(alpha: 0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isConsultation
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF2563EB))
                                  .withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getStatusDotColor(),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusDotColor().withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ref.watch(doctorProvider).name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isConsultation
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isConsultation
                                    ? (lang == 'fr'
                                        ? 'Consultation'
                                        : (lang == 'tr' ? 'Konsültasyon' : 'Consultation'))
                                    : (lang == 'fr'
                                        ? 'Pharmacie'
                                        : (lang == 'tr' ? 'Eczane' : 'Pharmacy')),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isConsultation
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Language Toggle (FR / EN / TR)
                      GestureDetector(
                        onTap: _toggleLanguage,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lang.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                CupertinoIcons.arrow_2_circlepath,
                                size: 10,
                                color: Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Animated Sphere Reacting to Audio Metering Level ────────
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _sphereShrinkController,
                    _speechService.soundLevelNotifier,
                    _spherePulseController,
                  ]),
                  builder: (context, child) {
                    final baseSize = _sphereSizeAnimation.value;
                    final topMargin = _sphereVerticalOffsetAnimation.value;

                    // Reactive sound scale (0.0 to 1.0)
                    final soundLevel = _speechService.soundLevelNotifier.value;
                    final isDetectingSpeech = _speechService.state == SpeechState.detectingSpeech;
                    final soundScale = isDetectingSpeech ? (1.0 + (soundLevel * 0.18)) : 1.0;

                    final pulse = (_speechService.state == SpeechState.listening)
                        ? _spherePulseController.value * 8.0
                        : 0.0;

                    final effectiveSize = (baseSize + pulse) * soundScale;

                    return Padding(
                      padding: EdgeInsets.only(top: topMargin, bottom: 8),
                      child: Center(
                        child: GestureDetector(
                          onTap: _toggleMic,
                          behavior: HitTestBehavior.opaque,
                          child: ClipOval(
                            clipBehavior: Clip.antiAlias,
                            child: SizedBox(
                              width: effectiveSize,
                              height: effectiveSize,
                              child: Image.asset(
                                'assets/animations/sphere.gif',
                                fit: BoxFit.cover,
                                width: effectiveSize,
                                height: effectiveSize,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      CupertinoIcons.mic_fill,
                                      color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                      size: effectiveSize * 0.4,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ── Status tag (only for processing / silence confirmation) ──
                _buildStatusChip(isDark, lang),

                // ── Main Content Area ───────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildMainContentArea(isDark, lang),
                  ),
                ),

                // ── Sleek Apple-style Voice Controls Dock ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Keyboard Button
                            _buildModernDockAction(
                              isDark: isDark,
                              icon: CupertinoIcons.keyboard,
                              label: lang == 'fr'
                                  ? 'Clavier'
                                  : (lang == 'tr' ? 'Klavye' : 'Keyboard'),
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              bgColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF1F5F9),
                              onTap: () => _openKeyboardModal(isDark, lang),
                            ),

                            // Hero Center Mic Button
                            _buildHeroMicButton(),

                            // End call / Quit Button
                            _buildModernDockAction(
                              isDark: isDark,
                              icon: CupertinoIcons.phone_down_fill,
                              label: lang == 'fr'
                                  ? 'Quitter'
                                  : (lang == 'tr' ? 'Çıkış' : 'End'),
                              color: const Color(0xFFEF4444),
                              bgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _autoResumeTimer?.cancel();
                                _speechService.cancel();
                                context.pop();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusDotColor() {
    final primary = isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    switch (_speechService.state) {
      case SpeechState.listening:
        return primary;
      case SpeechState.detectingSpeech:
        return const Color(0xFFEF4444);
      case SpeechState.silenceConfirmation:
        return const Color(0xFF06B6D4);
      case SpeechState.processing:
        return const Color(0xFFF59E0B);
      case SpeechState.responseReady:
        return primary;
      case SpeechState.error:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  // ── Status Chip Builder ────────────────────────────────────────────────────

  Widget _buildStatusChip(bool isDark, String lang) {
    // Hide status chip during listening, speech detection, response, or idle (clean per user request)
    if (_speechService.state == SpeechState.responseReady ||
        _speechService.state == SpeechState.listening ||
        _speechService.state == SpeechState.detectingSpeech ||
        _speechService.state == SpeechState.idle) {
      return const SizedBox.shrink();
    }

    String label;
    Color color;
    IconData icon;
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';

    switch (_speechService.state) {
      case SpeechState.requestingPermission:
        label = isFrench
            ? 'Demande d\'autorisation...'
            : (isTurkish ? 'İzin isteniyor...' : 'Requesting mic access...');
        color = const Color(0xFFF59E0B);
        icon = CupertinoIcons.lock_shield;
        break;
      case SpeechState.silenceConfirmation:
        label = isFrench
            ? 'Avez-vous terminé ?'
            : (isTurkish ? 'Bitirdiniz mi?' : 'Have you finished?');
        color = const Color(0xFF06B6D4);
        icon = CupertinoIcons.question_circle_fill;
        break;
      case SpeechState.processing:
        final docShort = ref.watch(doctorProvider).shortName;
        label = isConsultation
            ? (isFrench
                ? '$docShort analyse vos symptômes...'
                : (isTurkish ? '$docShort semptomları inceliyor...' : '$docShort analyzing symptoms...'))
            : (isFrench
                ? '$docShort consulte votre pharmacie...'
                : (isTurkish ? '$docShort eczanenize bakıyor...' : '$docShort checking pharmacy...'));
        color = const Color(0xFFF59E0B);
        icon = CupertinoIcons.hourglass;
        break;
      case SpeechState.error:
        label = isFrench
            ? 'Information vocale'
            : (isTurkish ? 'Sesli bilgi' : 'Voice status');
        color = const Color(0xFFF97316);
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Content Area ──────────────────────────────────────────────────────

  Widget _buildMainContentArea(bool isDark, String lang) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';

    // 1. Doctor Response: Left-aligned clean medical card
    if (_speechService.state == SpeechState.responseReady) {
      return _buildDoctorResponseCard(isDark, textColor, lang);
    }

    // 2. Doctor is Analyzing: Left-aligned clean card
    if (_speechService.state == SpeechState.processing) {
      return _buildAnalyzingCard(isDark, lang);
    }

    // 3. Silence Confirmation Window
    if (_speechService.state == SpeechState.silenceConfirmation) {
      return _buildSilenceConfirmationCard(isDark, lang, textColor);
    }

    // 4. Error State
    if (_speechService.state == SpeechState.error) {
      return _buildErrorCard(isDark, lang, textColor);
    }

    // 5. Active Voice Transcription (listening or detecting speech)
    return ValueListenableBuilder<String>(
      valueListenable: _speechService.transcriptNotifier,
      builder: (context, transcriptText, _) {
        final text = transcriptText.trim();
        final hasSpeech = text.isNotEmpty;

        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasSpeech
                      ? '« $text »'
                      : (isConsultation
                          ? (isFrench
                              ? 'Décrivez ce que vous ressentez...'
                              : (isTurkish ? 'Nasıl hissettiğinizi anlatın...' : 'Describe how you feel...'))
                          : (isFrench
                              ? 'Posez votre question ou demandez un médicament...'
                              : (isTurkish ? 'Sorunuzu veya ilacınızı sorun...' : 'Ask your question or search a medication...'))),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: -0.2,
                    color: hasSpeech
                        ? (isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                if (hasSpeech) ...[
                  const SizedBox(height: 16),
                  // Immediate Manual Finish Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: _onConfirmFinish,
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 16),
                    label: Text(
                      isFrench
                          ? 'Terminer maintenant'
                          : (isTurkish ? 'Şimdi bitir' : 'Finish now'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyzingCard(bool isDark, String lang) {
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.waveform_path,
                      size: 13,
                      color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ref.watch(doctorProvider).name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(radius: 8),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    isConsultation
                        ? (isFrench
                            ? 'Analyse de vos symptômes...'
                            : (isTurkish ? 'Semptomlarınız analiz ediliyor...' : 'Analyzing your symptoms...'))
                        : (isFrench
                            ? 'Recherche dans votre pharmacie...'
                            : (isTurkish ? 'İlaç dolabınız inceleniyor...' : 'Checking your pharmacy...')),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 10-Second Silence Confirmation Card ────────────────────────────────────

  Widget _buildSilenceConfirmationCard(bool isDark, String lang, Color textColor) {
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';
    final transcriptText = _speechService.transcript.trim();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isFrench
                        ? 'Avez-vous terminé ?'
                        : (isTurkish ? 'Cümlenizi tamamladınız mı?' : 'Have you finished speaking?'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              transcriptText.isNotEmpty ? '« $transcriptText »' : '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: textColor.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // "Continuer à parler"
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _onResumeSpeaking,
                    icon: const Icon(CupertinoIcons.mic, size: 16),
                    label: Text(
                      isFrench
                          ? 'Continuer'
                          : (isTurkish ? 'Devam et' : 'Continue'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // "Terminer"
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _onConfirmFinish,
                    icon: const Icon(CupertinoIcons.arrow_right, size: 16),
                    label: Text(
                      isFrench
                          ? 'Terminer'
                          : (isTurkish ? 'Tamamla' : 'Finish'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Error Card ─────────────────────────────────────────────────────────────

  Widget _buildErrorCard(bool isDark, String lang, Color textColor) {
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';
    final errorText = _speechService.errorMessage ??
        (isFrench ? 'Erreur de reconnaissance vocale' : 'Speech recognition error');

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFrench
                        ? 'Information Microphone'
                        : (isTurkish ? 'Mikrofon Bilgisi' : 'Microphone Notice'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              errorText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.4,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _openKeyboardModal(isDark, lang),
                    child: Text(
                      isFrench ? 'Écrire au clavier' : (isTurkish ? 'Klavye kullan' : 'Use keyboard'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _initAndStartVoice,
                    child: Text(
                      isFrench ? 'Réessayer' : (isTurkish ? 'Tekrar dene' : 'Retry'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Doctor Response Card (Clean, Left-Aligned Medical Bubble) ──────────────

  Widget _buildDoctorResponseCard(bool isDark, Color textColor, String lang) {
    final isFrench = lang == 'fr';
    final isDoneTyping = _currentSentenceIndex >= _doctorSentences.length;

    // Concatenate already completed sentences + current sentence fragment
    final pastText = _currentSentenceIndex > 0
        ? _doctorSentences.sublist(0, _currentSentenceIndex).join(' ')
        : '';
    final current = _displayedCurrentSentence;
    final accumulatedText = pastText.isEmpty
        ? current
        : (current.isEmpty ? pastText : '$pastText $current');

    return AnimatedBuilder(
      animation: _cursorBlinkController,
      builder: (context, _) {
        final showCursor = !isDoneTyping && (_cursorBlinkController.value > 0.45);

        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88,
              maxHeight: MediaQuery.of(context).size.height * (_recommendedMedication != null ? 0.52 : 0.42),
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB)).withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: Icon(
                              CupertinoIcons.waveform_path,
                              size: 13,
                              color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ref.watch(doctorProvider).name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    if (!isDoneTyping)
                      GestureDetector(
                        onTap: _fastForwardLyrics,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.forward_fill,
                                size: 10,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFrench ? 'Passer' : 'Skip',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Typing Content Body
                Flexible(
                  child: SingleChildScrollView(
                    controller: _lyricsScrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Text.rich(
                      TextSpan(
                        text: accumulatedText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: textColor,
                        ),
                        children: [
                          if (showCursor)
                            TextSpan(
                              text: ' ▍',
                              style: TextStyle(
                                color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_recommendedMedication != null) ...[
                  MedicationRecommendationCard(
                    medicationData: _recommendedMedication!,
                    onCustomTap: () {
                      _speechService.cancel();
                      final pharmacyState = ref.read(pharmacyProvider);
                      final scanId = (_recommendedMedication!['id'] ?? _recommendedMedication!['scan_id'] ?? '').toString();
                      RecentScan? matchedScan;
                      try {
                        matchedScan = pharmacyState.allScans.firstWhere(
                          (s) => s.scanId == scanId || s.id == scanId,
                        );
                      } catch (_) {
                        matchedScan = null;
                      }
                      if (matchedScan != null) {
                        context.push('/scan-result', extra: matchedScan.toJson());
                      } else {
                        context.push('/scan-result', extra: _recommendedMedication!);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Hero Center Action Button ───────────────────────────────────────────────

  Widget _buildHeroMicButton() {
    final state = _speechService.state;
    final isSilenceConfirm = state == SpeechState.silenceConfirmation;
    final isDetecting = state == SpeechState.detectingSpeech;
    final primaryColor = isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final detectingColor = isConsultation ? const Color(0xFF059669) : const Color(0xFF1D4ED8);

    Color buttonColor = primaryColor;
    IconData icon = CupertinoIcons.mic_fill;

    if (isSilenceConfirm) {
      buttonColor = const Color(0xFF06B6D4);
      icon = CupertinoIcons.checkmark_alt;
    } else if (isDetecting) {
      buttonColor = detectingColor;
      icon = CupertinoIcons.waveform;
    } else if (state == SpeechState.listening) {
      buttonColor = primaryColor;
      icon = CupertinoIcons.mic_fill;
    }

    return GestureDetector(
      onTap: _toggleMic,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              buttonColor,
              buttonColor.withValues(alpha: 0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ── Modern Dock Action Button ──────────────────────────────────────────────

  Widget _buildModernDockAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
