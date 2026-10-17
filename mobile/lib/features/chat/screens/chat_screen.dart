import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_session.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/medical_sources_widget.dart';
import '../providers/chat_provider.dart';
import '../providers/doctor_provider.dart';
import '../../../shared/utils/pill_notification.dart';

class ChatPage extends ConsumerStatefulWidget {
  /// Optional medication context injected from scan result screen.
  final String? medicationContext;
  /// Optional medication image URL from scan result screen.
  final String? medicationImageUrl;
  const ChatPage({super.key, this.medicationContext, this.medicationImageUrl});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _consultationScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  double _inputDragDelta = 0;
  bool _sending = false;
  bool _autoScrollEnabled = true;
  String? _lastInjectedMedication;

  // Toggle animation
  late AnimationController _tabController;

  // Cached notifier so dispose() never touches `ref` after unmount
  late final ChatInputActiveNotifier _chatInputActiveNotifier;

  @override
  void initState() {
    super.initState();
    _chatInputActiveNotifier = ref.read(chatInputActiveProvider.notifier);
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_syncChatInputActiveState);
    _messageController.addListener(_syncChatInputActiveState);

    final initialMode = ref.read(chatProvider.notifier).mode;
    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: initialMode == 'consultation' ? 1.0 : 0.0,
    );

    // Warm up backend in background to prevent Render cold-start latency
    _warmUpBackend();

    // Ensure input starts unfocused in idle state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
      _syncChatInputActiveState();
      _checkMedicationContext();
    });
  }

  void _syncChatInputActiveState() {
    if (!mounted) return;
    final isActive = _focusNode.hasFocus || _messageController.text.trim().isNotEmpty;
    _chatInputActiveNotifier.setActive(isActive);
    setState(() {});
  }

  void _warmUpBackend() {
    try {
      final healthUri = Uri.parse(ApiConstants.baseUrl.replaceAll('/api/v1', '') + '/health');
      http.get(healthUri).timeout(const Duration(seconds: 5)).then((_) {}).catchError((_) {});
    } catch (_) {}
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.medicationContext != null &&
        widget.medicationContext != oldWidget.medicationContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkMedicationContext();
      });
    }
  }

  void _checkMedicationContext() {
    final medName = widget.medicationContext;
    if (medName != null && medName.isNotEmpty && medName != _lastInjectedMedication) {
      _lastInjectedMedication = medName;
      ref.read(chatProvider.notifier).setMedicationContext(medName, imageUrl: widget.medicationImageUrl);
      ref.read(chatProvider.notifier).setMode('chat');
      _tabController.reverse();

      // Trigger automatic inquiry to Dr. Sarah about this medication
      final promptTemplate = ref.t('medicationChatPrompt');
      final promptText = promptTemplate.replaceAll('{name}', medName);

      // Auto-send after a short delay so the chat UI is rendered
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _sendDirect(promptText);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncChatInputActiveState);
    _messageController.removeListener(_syncChatInputActiveState);
    _focusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _consultationScrollController.dispose();
    _tabController.dispose();
    final notifier = _chatInputActiveNotifier;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        notifier.setActive(false);
      } catch (_) {}
    });
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 40) {
      if (!_autoScrollEnabled) setState(() => _autoScrollEnabled = true);
    } else {
      if (_autoScrollEnabled) setState(() => _autoScrollEnabled = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final bottomOffset = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        bottomOffset + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(bottomOffset);
    }
  }

  String _currentMode() => ref.read(chatProvider.notifier).mode;

  void _switchMode(String newMode) {
    if (_currentMode() == newMode) return;
    ref.read(chatProvider.notifier).setMode(newMode);
    if (newMode == 'consultation') {
      _tabController.forward();
    } else {
      _tabController.reverse();
    }
    setState(() {});
  }

  Future<void> _sendDirect(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _autoScrollEnabled = true;
    });

    final langCode = ref.read(languageProvider);

    try {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      await ref.read(chatProvider.notifier).sendMessage(trimmed, langCode);
      if (mounted) setState(() => _sending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      if (e.toString().contains('INSUFFICIENT_CREDITS') && mounted) {
        _showCreditsDialog(context);
      } else if (mounted) {
        showPillError(context, ref.t('chatError'));
      }
    }
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    _messageController.clear();
    await _sendDirect(text);
  }

  void _showCreditsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red[50]!.withOpacity(isDark ? 0.15 : 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('💎', style: TextStyle(fontSize: 32))),
              ),
              const SizedBox(height: 16),
              Text(ref.t('insufficientCredits'), style: AppTextStyles.h3(isDark: isDark)),
              const SizedBox(height: 12),
              Text(
                isAnonymous ? ref.t('trialOrSignInTagline') : ref.t('chatNoGems'),
                style: AppTextStyles.small(isDark: isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isAnonymous) ...[
                Button(
                  width: double.infinity,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/auth');
                  },
                  child: Text(ref.t('signInOrRegister')),
                ),
                const SizedBox(height: 12),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(ref.t('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatProvider);
    final isConsultation = _currentMode() == 'consultation';
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isChatInputActive = ref.watch(chatInputActiveProvider);

    // Height of CustomNavigationBar from screen bottom: 68 (pill) + (safeAreaBottom + 8) = ~110px.
    // Adding 12px breathing room floats the input bar cleanly above the nav bar in idle mode.
    final double navBarHeight = (safeAreaBottom > 0 ? safeAreaBottom + 8.0 : 20.0) + 68.0;
    final double idleSpacing = navBarHeight + 12.0;
    // When input is active, nav bar slides down off screen; input rests nicely above home indicator
    final double activeNoKeyboardSpacing = safeAreaBottom > 0 ? safeAreaBottom + 10.0 : 16.0;

    final double bottomSpacing = isKeyboardOpen
        ? 8.0
        : (isChatInputActive ? activeNoKeyboardSpacing : idleSpacing);

    // Auto scroll when new streaming chunks arrive
    ref.listen<String>(chatStreamingProvider, (previous, next) {
      if (next.isNotEmpty && _autoScrollEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F6FB),
      appBar: _buildAppBar(isDark, isConsultation),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF0B1120),
                  ]
                : [
                    const Color(0xFFE4F0F9),
                    const Color(0xFFF3F7FB),
                    Colors.white,
                  ],
            stops: isDark ? [0.0, 1.0] : [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Mode Pill Toggle ─────────────────────────────────────────
              ResponsiveContainer(
                child: _buildModeToggle(isDark, isConsultation),
              ),

              // ── Medical Disclaimer Banner ────────────────────────────────
              ResponsiveContainer(
                child: _buildDisclaimerBanner(isDark, isConsultation),
              ),

              // ── Messages Area (Tapping or scrolling unfocuses to slide nav bar back) ────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_focusNode.hasFocus) {
                      _focusNode.unfocus();
                    }
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification && _focusNode.hasFocus) {
                        _focusNode.unfocus();
                      }
                      return false;
                    },
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        const double fadeHeight = 28.0;
                        final double stop = bounds.height > 0
                            ? (fadeHeight / bounds.height).clamp(0.01, 0.12)
                            : 0.04;
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Colors.transparent,
                            Colors.black,
                          ],
                          stops: [0.0, stop],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ResponsiveContainer(
                        child: chatState.when(
                          loading: () => isConsultation
                              ? _buildConsultationWelcome(isDark)
                              : _buildChatWelcome(isDark),
                          error: (err, stack) => Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Text(ref.t('chatError'),
                                  style: AppTextStyles.small(isDark: isDark),
                                  textAlign: TextAlign.center),
                            ),
                          ),
                          data: (messages) {
                            if (messages.isEmpty) {
                              return isConsultation
                                  ? _buildConsultationWelcome(isDark)
                                  : _buildChatWelcome(isDark);
                            }
                            return _buildMessageList(isDark, messages);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Input Bar with fluid animated sliding ────────────────────
              AnimatedPadding(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                padding: EdgeInsets.only(bottom: bottomSpacing),
                child: ResponsiveContainer(
                  child: _buildInputBar(isDark, isConsultation),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(bool isDark, bool isConsultation) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 44,
      titleSpacing: 14,
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A3B5D).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    ref.watch(doctorProvider).imagePath,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.65),
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF2563EB), size: 18),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ref.watch(doctorProvider).name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 15),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${ref.t('online')} • ${ref.t('respondsQuickly')}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        // Sleek Burger Menu Button (groups "Nouvelle conversation" + "Historique")
        Padding(
          padding: const EdgeInsets.only(right: 14.0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showChatMenu(context, isDark);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A3B5D).withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  size: 19,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showChatMenu(BuildContext context, bool isDark) {
    final isFrench = ref.read(languageProvider) == 'fr';
    final sessionsCount =
        ref.read(chatSessionsProvider).where((s) => s.messages.isNotEmpty).length;
    final currentMessages = ref.read(chatProvider).asData?.value ?? [];
    final hasMessages = currentMessages.isNotEmpty;
    final isConsultation = _currentMode() == 'consultation';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          elevation: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isFrench ? 'Discussions & Actions' : 'Conversations & Actions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.xmark,
                                size: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildMenuAction(
                        isDark: isDark,
                        icon: CupertinoIcons.pencil,
                        iconColor: const Color(0xFF2563EB),
                        iconBgColor: isDark
                            ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                            : const Color(0xFFEFF6FF),
                        title: ref.t('newConversation'),
                        subtitle: isFrench
                            ? 'Repartir sur une page blanche'
                            : 'Start from a blank page',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(dialogContext);
                          ref.read(chatProvider.notifier).startNewSession();
                          showPillSuccess(context, ref.t('newConversationStarted'));
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMenuAction(
                        isDark: isDark,
                        icon: CupertinoIcons.clock,
                        iconColor: const Color(0xFF64748B),
                        iconBgColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9),
                        title: ref.t('chatHistoryTitle'),
                        subtitle: isFrench
                            ? 'Retrouver vos échanges précédents'
                            : 'Find your previous chats',
                        badge: sessionsCount > 0 ? '$sessionsCount' : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(dialogContext);
                          _showHistorySheet(context, isDark);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMenuAction(
                        isDark: isDark,
                        icon: isConsultation
                            ? CupertinoIcons.chat_bubble_2_fill
                            : CupertinoIcons.waveform_path,
                        iconColor: isConsultation
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF10B981),
                        iconBgColor: isConsultation
                            ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        title: isConsultation
                            ? (isFrench ? 'Passer en Chat classique' : 'Switch to Standard Chat')
                            : (isFrench ? 'Passer en Pré-consultation' : 'Switch to Pre-consultation'),
                        subtitle: isConsultation
                            ? (isFrench ? 'Questions médicales générales' : 'General medical Q&A')
                            : (isFrench ? 'Évaluation clinique guidée' : 'Guided clinical triage'),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(dialogContext);
                          final newMode = isConsultation ? 'chat' : 'consultation';
                          ref.read(chatProvider.notifier).setMode(newMode);
                          showPillSuccess(
                            context,
                            newMode == 'consultation'
                                ? (isFrench ? 'Mode Pré-consultation activé' : 'Pre-consultation mode active')
                                : (isFrench ? 'Mode Chat classique activé' : 'Standard Chat mode active'),
                          );
                          setState(() {});
                        },
                      ),
                      if (hasMessages) ...[
                        const SizedBox(height: 8),
                        _buildMenuAction(
                          isDark: isDark,
                          icon: CupertinoIcons.trash,
                          iconColor: const Color(0xFFEF4444),
                          iconBgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          title: isFrench ? 'Effacer cette discussion' : 'Clear this conversation',
                          subtitle: isFrench
                              ? 'Supprimer les messages en cours'
                              : 'Clear current messages',
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(dialogContext);
                            ref.read(chatProvider.notifier).clearHistory();
                            showPillSuccess(
                              context,
                              isFrench ? 'Discussion effacée' : 'Conversation cleared',
                            );
                            setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuAction({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSessionTime(DateTime dt, bool isFrench) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 1) {
      return isFrench ? "À l'instant" : "Just now";
    }
    if (difference.inHours < 1) {
      return isFrench ? "Il y a ${difference.inMinutes} min" : "${difference.inMinutes}m ago";
    }
    if (difference.inDays < 1 && now.day == dt.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return "$hour:$min";
    }
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return "$day/$month";
  }

  Map<String, List<ChatSession>> _groupSessionsByDate(List<ChatSession> sessions, bool isFrench) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
    final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

    final Map<String, List<ChatSession>> groups = {};

    final todayLabel = isFrench ? "Aujourd'hui" : "Today";
    final yesterdayLabel = isFrench ? "Hier" : "Yesterday";
    final weekLabel = isFrench ? "7 derniers jours" : "Previous 7 days";
    final monthLabel = isFrench ? "30 derniers jours" : "Previous 30 days";
    final olderLabel = isFrench ? "Plus ancien" : "Older";

    for (final s in sessions) {
      if (s.messages.isEmpty) continue;
      final date = s.updatedAt;
      if (date.isAfter(todayStart)) {
        groups.putIfAbsent(todayLabel, () => []).add(s);
      } else if (date.isAfter(yesterdayStart)) {
        groups.putIfAbsent(yesterdayLabel, () => []).add(s);
      } else if (date.isAfter(sevenDaysAgo)) {
        groups.putIfAbsent(weekLabel, () => []).add(s);
      } else if (date.isAfter(thirtyDaysAgo)) {
        groups.putIfAbsent(monthLabel, () => []).add(s);
      } else {
        groups.putIfAbsent(olderLabel, () => []).add(s);
      }
    }
    return groups;
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHistorySheet(BuildContext context, bool isDark) {
    final isFrench = ref.read(languageProvider) == 'fr';
    final initialMode = ref.read(chatProvider.notifier).mode;
    String filterMode = initialMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Consumer(
              builder: (context, ref, _) {
                final sessions = ref.watch(chatSessionsProvider);
                final activeSessionId = ref.watch(activeChatSessionIdProvider);

                final filteredSessions = sessions.where((s) {
                  if (filterMode == 'chat') return s.mode != 'consultation';
                  if (filterMode == 'consultation') return s.mode == 'consultation';
                  return true;
                }).toList();

                final groups = _groupSessionsByDate(filteredSessions, isFrench);

                return DraggableScrollableSheet(
                  initialChildSize: 0.78,
                  minChildSize: 0.45,
                  maxChildSize: 0.94,
                  expand: false,
                  builder: (_, scrollCtrl) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Drag Handle
                          Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Header Bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isFrench ? 'Discussions récentes' : 'Recent chats',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        isFrench ? 'Historique de vos échanges' : 'Your conversation history',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // + Nouvelle button (clean minimal iOS button)
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.pop(ctx);
                                    final targetMode = (filterMode == 'consultation')
                                        ? 'consultation'
                                        : (filterMode == 'chat' ? 'chat' : ref.read(chatProvider.notifier).mode);
                                    ref.read(chatProvider.notifier).startNewSession(mode: targetMode);
                                    if (targetMode == 'consultation') {
                                      _tabController.forward();
                                    } else {
                                      _tabController.reverse();
                                    }
                                    showPillSuccess(context, ref.t('newConversationStarted'));
                                    setState(() {});
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.plus,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isFrench ? 'Nouvelle' : 'New',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Segmented Mode Filter Bar (Apple-native clean)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  _buildFilterTab(
                                    label: isFrench ? 'Toutes' : 'All',
                                    isSelected: filterMode == 'all',
                                    isDark: isDark,
                                    onTap: () => setSheetState(() => filterMode = 'all'),
                                  ),
                                  _buildFilterTab(
                                    label: 'Chat',
                                    isSelected: filterMode == 'chat',
                                    isDark: isDark,
                                    onTap: () => setSheetState(() => filterMode = 'chat'),
                                  ),
                                  _buildFilterTab(
                                    label: isFrench ? 'Pré-consultation' : 'Consultation',
                                    isSelected: filterMode == 'consultation',
                                    isDark: isDark,
                                    onTap: () => setSheetState(() => filterMode = 'consultation'),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Divider(
                            height: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                          ),

                          // Content (List of sessions grouped by date or Empty State)
                          Expanded(
                            child: groups.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.05)
                                                  : const Color(0xFFF1F5F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                filterMode == 'consultation'
                                                    ? CupertinoIcons.heart
                                                    : CupertinoIcons.chat_bubble_2,
                                                size: 24,
                                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            filterMode == 'consultation'
                                                ? (isFrench ? 'Aucune pré-consultation' : 'No saved consultations')
                                                : (filterMode == 'chat'
                                                    ? (isFrench ? 'Aucune discussion chat' : 'No saved chats')
                                                    : (isFrench ? 'Aucune discussion archivée' : 'No saved conversations')),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            filterMode == 'consultation'
                                                ? (isFrench
                                                    ? 'Vos bilans et pré-consultations seront archivés ici.'
                                                    : 'Your medical pre-consultations will be saved here.')
                                                : (isFrench
                                                    ? 'Vos échanges seront automatiquement archivés ici.'
                                                    : 'Your conversations will automatically be grouped here.'),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollCtrl,
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                                    itemCount: groups.length,
                                    itemBuilder: (context, groupIndex) {
                                      final groupName = groups.keys.elementAt(groupIndex);
                                      final groupSessions = groups[groupName]!;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                                            child: Text(
                                              groupName.toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                          ...groupSessions.map((session) {
                                            final isActive = session.id == activeSessionId;
                                            final isConsultation = session.mode == 'consultation';

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? (isActive ? const Color(0xFF1E293B) : Colors.transparent)
                                                    : (isActive ? const Color(0xFFF8FAFC) : Colors.transparent),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: isActive
                                                      ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    HapticFeedback.lightImpact();
                                                    Navigator.pop(ctx);
                                                    ref.read(chatProvider.notifier).loadSession(session.id);
                                                    if (session.mode == 'consultation') {
                                                      _tabController.forward();
                                                    } else {
                                                      _tabController.reverse();
                                                    }
                                                    setState(() {});
                                                  },
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration: BoxDecoration(
                                                            color: isConsultation
                                                                ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5))
                                                                : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF)),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: Icon(
                                                            isConsultation ? CupertinoIcons.heart_fill : CupertinoIcons.chat_bubble_fill,
                                                            color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                                            size: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                session.title,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: GoogleFonts.plusJakartaSans(
                                                                  fontSize: 14,
                                                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                                ),
                                                              ),
                                                              const SizedBox(height: 3),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                                    decoration: BoxDecoration(
                                                                      color: isConsultation
                                                                          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5))
                                                                          : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)),
                                                                      borderRadius: BorderRadius.circular(5),
                                                                    ),
                                                                    child: Text(
                                                                      isConsultation ? 'Consultation' : 'Chat',
                                                                      style: GoogleFonts.plusJakartaSans(
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  Text(
                                                                    '${session.messages.length} msg • ${_formatSessionTime(session.updatedAt, isFrench)}',
                                                                    style: GoogleFonts.plusJakartaSans(
                                                                      fontSize: 11.5,
                                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (isActive) ...[
                                                          Container(
                                                            width: 6,
                                                            height: 6,
                                                            decoration: BoxDecoration(
                                                              color: isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                        ],
                                                        GestureDetector(
                                                          onTap: () => _confirmDeleteSession(context, session, isDark, isFrench),
                                                          behavior: HitTestBehavior.opaque,
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(6.0),
                                                            child: Icon(
                                                              CupertinoIcons.trash,
                                                              size: 15,
                                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSession(BuildContext context, ChatSession session, bool isDark, bool isFrench) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) {
        return CupertinoAlertDialog(
          title: Text(isFrench ? 'Supprimer la discussion ?' : 'Delete conversation?'),
          content: Text(
            isFrench
                ? 'Voulez-vous supprimer définitivement « ${session.title} » ?'
                : 'Do you want to permanently delete "${session.title}"?',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isFrench ? 'Annuler' : 'Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(dialogCtx);
                ref.read(chatProvider.notifier).deleteSession(session.id);
                showPillSuccess(context, isFrench ? 'Discussion supprimée' : 'Conversation deleted');
                setState(() {});
              },
              child: Text(isFrench ? 'Supprimer' : 'Delete'),
            ),
          ],
        );
      },
    );
  }

  // ─── Modern Segmented Mode Selector ───────────────────────────────────────

  Widget _buildModeToggle(bool isDark, bool isConsultation) {
    final activeColor =
        isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.85)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFCBD5E1).withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          // Animated sliding pill capsule
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment:
                isConsultation ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isConsultation
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Interactive Segment Items
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _switchMode('chat');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_2_fill,
                          size: 15,
                          color: !isConsultation
                              ? Colors.white
                              : (isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ref.t('chatModeChat'),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: !isConsultation
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 12.5,
                            letterSpacing: -0.2,
                            color: !isConsultation
                                ? Colors.white
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _switchMode('consultation');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.waveform_path_ecg,
                          size: 15,
                          color: isConsultation
                              ? Colors.white
                              : (isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ref.t('chatModeConsultation'),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: isConsultation
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 12.5,
                            letterSpacing: -0.2,
                            color: isConsultation
                                ? Colors.white
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Compact Micro-Disclaimer Banner ───────────────────────────────────────

  Widget _buildDisclaimerBanner(bool isDark, bool isConsultation) {
    final color =
        isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final icon = isConsultation
        ? CupertinoIcons.shield_lefthalf_fill
        : CupertinoIcons.info_circle_fill;
    final text = isConsultation
        ? ref.t('consultationDisclaimer')
        : ref.t('disclaimerMedical');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.18 : 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : color.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chat Welcome Screen ──────────────────────────────────────────────────

  Widget _buildChatWelcome(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 14),
          // Doctor Presentation directly on body (No enclosing card/cadran)
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    width: 2.0,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    ref.watch(doctorProvider).imagePath,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.65),
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(3),
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    width: 2.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ref.t('doctorGreeting'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              ref.t('doctorDescription'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          // Frequently Asked Questions Header (No sparkles)
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.question_circle_fill,
                    size: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ref.t('frequentlyAskedQuestions'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSuggestionItem(
            ref.t('faqQuestion1'),
            Icons.medical_services_rounded,
            const Color(0xFF2563EB),
          ),
          _buildSuggestionItem(
            ref.t('faqQuestion2'),
            CupertinoIcons.exclamationmark_triangle_fill,
            const Color(0xFFF59E0B),
          ),
          _buildSuggestionItem(
            ref.t('faqQuestion3'),
            CupertinoIcons.thermometer,
            const Color(0xFF06B6D4),
          ),
          const SizedBox(height: 130),
        ],
      ),
    );
  }

  // ─── Consultation Welcome Screen ──────────────────────────────────────────

  Widget _buildConsultationWelcome(bool isDark) {
    const green = Color(0xFF10B981);

    return SingleChildScrollView(
      controller: _consultationScrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 14),
          // Doctor Presentation directly on body (No enclosing card/cadran, no glow, no AI pill)
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    width: 2.0,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    ref.watch(doctorProvider).imagePath,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.65),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      color: green,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    width: 2.2,
                  ),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ref.t('consultationWelcomeTitle'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              ref.t('consultationWelcomeDesc'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),

          // How it works header
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Center(
                  child: Icon(
                    Icons.format_list_numbered_rounded,
                    size: 14,
                    color: green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ref.t('consultationHowItWorks') == 'consultationHowItWorks'
                    ? (ref.read(languageProvider) == 'fr'
                        ? 'Comment ça fonctionne'
                        : 'How it works')
                    : ref.t('consultationHowItWorks'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // How it works steps (Clean, on the body, no heavy cadrans)
          _buildConsultationStepCard(
            isDark: isDark,
            step: '1',
            icon: CupertinoIcons.chat_bubble_2_fill,
            title: ref.t('consultationStep1Title'),
            desc: ref.t('consultationStep1Desc'),
            color: green,
          ),
          _buildConsultationStepCard(
            isDark: isDark,
            step: '2',
            icon: CupertinoIcons.question_diamond_fill,
            title: ref.t('consultationStep2Title'),
            desc: ref.t('consultationStep2Desc'),
            color: const Color(0xFF3B82F6),
          ),
          _buildConsultationStepCard(
            isDark: isDark,
            step: '3',
            icon: CupertinoIcons.location_fill,
            title: ref.t('consultationStep3Title'),
            desc: ref.t('consultationStep3Desc'),
            color: const Color(0xFFF59E0B),
          ),
          _buildConsultationStepCard(
            isDark: isDark,
            step: '4',
            icon: CupertinoIcons.doc_text_fill,
            title: ref.t('consultationStep4Title'),
            desc: ref.t('consultationStep4Desc'),
            color: const Color(0xFFEC4899),
          ),

          const SizedBox(height: 18),
          // Start CTA (Clean, no AI sparkles)
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _messageController.text = ref.t('consultationStartPrompt');
              _handleSend();
            },
            child: Container(
              width: double.infinity,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ref.t('consultationStart'),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 130),
        ],
      ),
    );
  }

  Widget _buildConsultationStepCard({
    required bool isDark,
    required String step,
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message List ─────────────────────────────────────────────────────────

  Widget _buildMessageList(bool isDark, List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.role == 'user';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white24
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A3B5D).withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      ref.watch(doctorProvider).imagePath,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.65),
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF2563EB), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.82),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser
                              ? (isDark
                                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.6)
                                  : const Color(0xFFE0F2FE))
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isUser ? 18 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 18),
                          ),
                          border: Border.all(
                            color: isUser
                                ? (isDark
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                                    : const Color(0xFFBAE6FD))
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0)),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.18 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isUser
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Show medication image if attached
                                  if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: (msg.imageUrl!.startsWith('http') || !File(msg.imageUrl!).existsSync())
                                          ? CachedNetworkImage(
                                              imageUrl: ApiConstants.resolveImageUrl(msg.imageUrl!),
                                              width: 170,
                                              height: 110,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 170,
                                                height: 110,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => const SizedBox.shrink(),
                                            )
                                          : Image.file(
                                              File(msg.imageUrl!),
                                              width: 170,
                                              height: 110,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                            ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    msg.content,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.42,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              )
                            : (index == messages.length - 1 &&
                                    msg.content.isEmpty
                                ? const StreamingMarkdownWidget()
                                : MarkdownBody(
                                    data: msg.content,
                                    styleSheet:
                                        MarkdownStyleSheet.fromTheme(
                                                Theme.of(context))
                                            .copyWith(
                                      p: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w400,
                                        height: 1.48,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                      listBullet:
                                          GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                    if (!isUser) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showMedicalSourcesSheet(context, isDark),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_shield_fill,
                                size: 11,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Sources médicales vérifiées',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 9,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white24
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A3B5D).withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: () {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      final avatarPath = currentUser?.photoURL;
                      if (avatarPath != null && avatarPath.isNotEmpty) {
                        if (avatarPath.startsWith('http')) {
                          return CachedNetworkImage(
                            imageUrl: avatarPath,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.person,
                                color: Color(0xFF2563EB), size: 18),
                          );
                        }
                        return Image.asset(
                          avatarPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person,
                              color: Color(0xFF2563EB), size: 18),
                        );
                      }
                      return const Icon(Icons.person,
                          color: Color(0xFF2563EB), size: 18);
                    }(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Input Bar ────────────────────────────────────────────────────────────

  Widget _buildInputBar(bool isDark, bool isConsultation) {
    final accentColor =
        isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final hintKey =
        isConsultation ? 'consultationPlaceholder' : 'chatPlaceholder';
    final hasText = _messageController.text.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) {
        _inputDragDelta = 0;
      },
      onVerticalDragUpdate: (details) {
        _inputDragDelta += details.delta.dy;
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // Glisser vers le haut (tirer l'input vers le haut -> ouvrir clavier)
        if (_inputDragDelta < -15 || velocity < -120) {
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        }
        // Glisser vers le bas (rabaisser l'input -> fermer clavier et montrer navbar)
        else if (_inputDragDelta > 15 || velocity > 120) {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        }
        _inputDragDelta = 0;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A3B5D).withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 5, 5, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  cursorColor: accentColor,
                  decoration: InputDecoration(
                    hintText: isConsultation
                        ? ref.t('consultationPlaceholder')
                        : (ref.t(hintKey) == 'Ask your question...'
                            ? 'Ask me anything'
                            : ref.t(hintKey)),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Circular nested Action Button (Pastel sky blue mic <-> Send arrow)
              Opacity(
                opacity: _sending ? 0.4 : 1.0,
                child: GestureDetector(
                  onTap: _sending
                      ? null
                      : (hasText
                          ? _handleSend
                          : () async {
                              HapticFeedback.mediumImpact();
                              final returnedText = await context.push<String>('/voice-consultation');
                              if (returnedText != null && returnedText.isNotEmpty && mounted) {
                                _messageController.text = returnedText;
                                setState(() {});
                              }
                            }),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasText
                          ? (isConsultation
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2563EB))
                          : (isConsultation
                              ? (isDark
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFFA7F3D0))
                              : (isDark
                                  ? const Color(0xFF1E3A8A)
                                      .withValues(alpha: 0.65)
                                  : const Color(0xFFBAE6FD))),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                              opacity: animation, child: child),
                        ),
                        child: hasText
                            ? const Icon(
                                Icons.arrow_upward_rounded,
                                key: ValueKey('arrow_send'),
                                color: Colors.white,
                                size: 20,
                              )
                            : Icon(
                                CupertinoIcons.mic_fill,
                                key: const ValueKey('mic_voice'),
                                color: isConsultation
                                    ? (isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF065F46))
                                    : (isDark
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF0284C7)),
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Suggestion Item ──────────────────────────────────────────────────────

  Widget _buildSuggestionItem(String text, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _messageController.text = text;
            _handleSend();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.16 : 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, color: color, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.35,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMedicalSourcesSheet(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MedicalSourcesWidget(
                        medicationName: '',
                        isAiResponse: true,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Fermer',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  void _showVoiceCommandSheet(
      BuildContext context, bool isDark, bool isConsultation) {
    HapticFeedback.mediumImpact();
    final accentColor =
        isConsultation ? const Color(0xFF10B981) : const Color(0xFF2563EB);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _VoiceCommandSheet(
          isDark: isDark,
          isConsultation: isConsultation,
          accentColor: accentColor,
          onQuestionSelected: (question) {
            Navigator.pop(sheetContext);
            _messageController.text = question;
            _syncChatInputActiveState();
            _handleSend();
          },
        );
      },
    );
  }
}

// ─── Streaming Markdown Widget ────────────────────────────────────────────────

class StreamingMarkdownWidget extends ConsumerWidget {
  const StreamingMarkdownWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streamText = ref.watch(chatStreamingProvider);

    if (streamText.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) => _BlinkingDot(delay: index * 200)),
          ),
        ),
      );
    }

    return MarkdownBody(
      data: streamText,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: AppTextStyles.small(isDark: isDark).copyWith(height: 1.5),
        listBullet: AppTextStyles.small(isDark: isDark),
      ),
    );
  }
}

// ─── Blinking Dot Animation ───────────────────────────────────────────────────

class _BlinkingDot extends StatefulWidget {
  final int delay;
  const _BlinkingDot({required this.delay});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: isDark ? Colors.white60 : Colors.black45,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Voice Command Sheet Widget ───────────────────────────────────────────────

class _VoiceCommandSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final bool isConsultation;
  final Color accentColor;
  final ValueChanged<String> onQuestionSelected;

  const _VoiceCommandSheet({
    required this.isDark,
    required this.isConsultation,
    required this.accentColor,
    required this.onQuestionSelected,
  });

  @override
  ConsumerState<_VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

class _VoiceCommandSheetState extends ConsumerState<_VoiceCommandSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accentColor = widget.accentColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isConsultation
                                  ? 'Assistant Médical Vocal'
                                  : 'Commande Vocale IA',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Animated pulsating microphone orb
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.12);
                      final waveScale1 = 1.0 + (_pulseController.value * 0.35);
                      final waveScale2 = 1.0 + (_pulseController.value * 0.65);
                      final opacity1 = (1.0 - _pulseController.value) * 0.25;
                      final opacity2 = (1.0 - _pulseController.value) * 0.15;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: waveScale2,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withOpacity(opacity2),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: waveScale1,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withOpacity(opacity1),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor,
                                    HSLColor.fromColor(accentColor)
                                        .withLightness((HSLColor.fromColor(accentColor).lightness - 0.1).clamp(0.0, 1.0))
                                        .toColor(),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.mic_fill,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Parlez à ${ref.watch(doctorProvider).shortName}...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Posez votre question à haute voix ou touchez une suggestion ci-dessous :',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Quick suggestions
                  Column(
                    children: [
                      _buildQuickPrompt(
                        context,
                        icon: CupertinoIcons.capsule_fill,
                        text: widget.isConsultation
                            ? 'Décrire mes symptômes actuels'
                            : 'Quelle est la posologie habituelle de ce traitement ?',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildQuickPrompt(
                        context,
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        text: widget.isConsultation
                            ? 'J\'ai une fièvre persistante depuis 2 jours'
                            : 'Quels sont les effets secondaires fréquents ?',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildQuickPrompt(
                        context,
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        text: widget.isConsultation
                            ? 'Est-ce compatible avec mes antécédents ?'
                            : 'Puis-je associer ce médicament avec d\'autres prises ?',
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(
    BuildContext context, {
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onQuestionSelected(text);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: widget.accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.arrow_up_right,
                size: 13,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

