import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/chat_message.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/medical_sources_widget.dart';
import '../providers/chat_provider.dart';
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
  final FocusNode _focusNode = FocusNode();
  double _inputDragDelta = 0;
  bool _sending = false;
  bool _autoScrollEnabled = true;
  String? _lastInjectedMedication;

  // Toggle animation
  late AnimationController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Warm up backend in background to prevent Render cold-start latency
    _warmUpBackend();

    // Inject medication context if navigated from scan result
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMedicationContext();
      _scrollToBottom(animated: false);
    });
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
    _focusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
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
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Clearance: Nav bar height (85) + central FAB protrusion (24) + generous breathing room (16) = 125.
    // When keyboard is open, the floating nav bar is automatically hidden by AppShell, so we only need clean padding.
    final double bottomSpacing = isKeyboardOpen ? 8.0 : 125.0;

    // Auto scroll when new streaming chunks arrive
    ref.listen<String>(chatStreamingProvider, (previous, next) {
      if (next.isNotEmpty && _autoScrollEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: _buildAppBar(isDark, isConsultation),
      body: SafeArea(
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

            // ── Messages Area ────────────────────────────────────────────
            Expanded(
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

            // ── Input Bar ────────────────────────────────────────────────
            ResponsiveContainer(
              child: _buildInputBar(isDark, isConsultation),
            ),

            SizedBox(height: bottomSpacing),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(bool isDark, bool isConsultation) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: AssetImage('assets/images/doctor-png.jpg'),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.backgroundDark : Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(ref.t('doctorName'),
                        style: AppTextStyles.bodyBold(isDark: isDark)
                            .copyWith(fontSize: 15)),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 14),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(ref.t('online'),
                        style: AppTextStyles.micro(isDark: isDark)
                            .copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(ref.t('respondsQuickly'),
                        style: AppTextStyles.micro(isDark: isDark).copyWith(
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        // Chat History button
        IconButton(
          onPressed: () => _showHistorySheet(context, isDark),
          icon: Icon(
            Icons.history_rounded,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            size: 24,
          ),
          tooltip: ref.t('chatHistoryTitle'),
        ),
        // New Conversation button
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            onPressed: () {
              final messages = ref.read(chatProvider).value ?? [];
              if (messages.isEmpty) {
                showPillSuccess(context, ref.t('alreadyNewConversation'));
              } else {
                ref.read(chatProvider.notifier).clearHistory();
                showPillSuccess(context, ref.t('newConversationStarted'));
                setState(() {});
              }
            },
            icon: Icon(
              Icons.add_comment_outlined,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              size: 22,
            ),
            tooltip: ref.t('newConversation'),
          ),
        ),
      ],
    );
  }

  void _showHistorySheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final messages = ref.watch(chatProvider).value ?? [];
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.history_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                ref.t('chatHistoryTitle'),
                                style: AppTextStyles.h3(isDark: isDark),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref.read(chatProvider.notifier).reloadHistory();
                              if (ctx.mounted) {
                                showPillSuccess(context, ref.t('refreshHistory'));
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 22),
                            tooltip: ref.t('refreshHistory'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Content
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 48,
                                      color: isDark
                                          ? AppColors.textMutedDark
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      ref.t('chatHistoryEmpty'),
                                      style: AppTextStyles.small(isDark: isDark),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: messages.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final msg = messages[index];
                                final isUser = msg.role == 'user';
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? (isUser ? const Color(0x1A2563EB) : const Color(0x0DFFFFFF))
                                        : (isUser ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0x1AFFFFFF)
                                          : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isUser ? 'Vous' : ref.t('doctorName'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isUser
                                                  ? AppColors.primary
                                                  : (isDark ? Colors.white70 : Colors.black87),
                                            ),
                                          ),
                                          Text(
                                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg.content.trim().isEmpty ? '...' : msg.content.trim(),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Mode Toggle Pills ────────────────────────────────────────────────────

  Widget _buildModeToggle(bool isDark, bool isConsultation) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildPillButton(
            isDark: isDark,
            label: ref.t('chatModeChat'),
            icon: Icons.chat_bubble_outline_rounded,
            isSelected: !isConsultation,
            color: AppColors.primary,
            onTap: () => _switchMode('chat'),
          ),
          _buildPillButton(
            isDark: isDark,
            label: ref.t('chatModeConsultation'),
            icon: Icons.medical_services_outlined,
            isSelected: isConsultation,
            color: const Color(0xFF10B981), // emerald
            onTap: () => _switchMode('consultation'),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(46),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.small(isDark: isDark).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white60 : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Disclaimer Banner ────────────────────────────────────────────────────

  Widget _buildDisclaimerBanner(bool isDark, bool isConsultation) {
    final color = isConsultation ? const Color(0xFF10B981) : AppColors.primary;
    final icon = isConsultation ? Icons.health_and_safety_outlined : Icons.shield_outlined;
    final text = isConsultation
        ? ref.t('consultationDisclaimer')
        : ref.t('disclaimerMedical');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  color.withOpacity(0.12),
                  color.withOpacity(0.06),
                ]
              : [
                  color.withOpacity(0.08),
                  color.withOpacity(0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.25 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.micro(isDark: isDark).copyWith(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : color.withOpacity(0.85),
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Doctor Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 4,
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 44,
                        backgroundImage: AssetImage('assets/images/doctor-png.jpg'),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  ref.t('doctorGreeting'),
                  style: AppTextStyles.h2(isDark: isDark)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  ref.t('doctorDescription'),
                  style: AppTextStyles.small(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ).copyWith(height: 1.5, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ref.t('frequentlyAskedQuestions'),
              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(height: 12),
          _buildSuggestionItem(ref.t('faqQuestion1'), Icons.medication_outlined, AppColors.primary),
          _buildSuggestionItem(ref.t('faqQuestion2'), Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
          _buildSuggestionItem(ref.t('faqQuestion3'), Icons.thermostat_outlined, const Color(0xFF06B6D4)),
        ],
      ),
    );
  }

  // ─── Consultation Welcome Screen ──────────────────────────────────────────

  Widget _buildConsultationWelcome(bool isDark) {
    final green = const Color(0xFF10B981);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Consultation Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [green.withOpacity(0.15), green.withOpacity(0.05)]
                    : [green.withOpacity(0.08), green.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: green.withOpacity(isDark ? 0.3 : 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.medical_services_rounded, color: green, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  ref.t('consultationWelcomeTitle'),
                  style: AppTextStyles.h2(isDark: isDark)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  ref.t('consultationWelcomeDesc'),
                  style: AppTextStyles.small(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ).copyWith(height: 1.6, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // How it works steps
          _buildConsultationStepCard(
            isDark: isDark,
            step: '1',
            icon: Icons.chat_outlined,
            title: ref.t('consultationStep1Title'),
            desc: ref.t('consultationStep1Desc'),
            color: green,
          ),
          _buildConsultationStepCard(
            isDark: isDark,
            step: '2',
            icon: Icons.quiz_outlined,
            title: ref.t('consultationStep2Title'),
            desc: ref.t('consultationStep2Desc'),
            color: const Color(0xFF3B82F6),
          ),
          _buildConsultationStepCard(
            isDark: isDark,
            step: '3',
            icon: Icons.location_on_outlined,
            title: ref.t('consultationStep3Title'),
            desc: ref.t('consultationStep3Desc'),
            color: const Color(0xFFF59E0B),
          ),
          _buildConsultationStepCard(
            isDark: isDark,
            step: '4',
            icon: Icons.assignment_outlined,
            title: ref.t('consultationStep4Title'),
            desc: ref.t('consultationStep4Desc'),
            color: const Color(0xFFEC4899),
          ),

          const SizedBox(height: 16),
          // Start CTA
          GestureDetector(
            onTap: () {
              _messageController.text = ref.t('consultationStartPrompt');
              _handleSend();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [green, green.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    ref.t('consultationStart'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.small(isDark: isDark)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: AppTextStyles.micro(isDark: isDark).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/doctor-png.jpg',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isUser ? null : double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primary
                            : (isDark ? AppColors.cardDark : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft:
                              Radius.circular(isUser ? 20 : 0),
                          bottomRight:
                              Radius.circular(isUser ? 0 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                            width: 180,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 180,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
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
                                            width: 180,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  msg.content,
                                  style: AppTextStyles.small(isDark: false)
                                      .copyWith(color: Colors.white),
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
                                    p: AppTextStyles.small(isDark: isDark)
                                        .copyWith(height: 1.5),
                                    listBullet:
                                        AppTextStyles.small(isDark: isDark),
                                  ),
                                )),
                    ),
                    if (!isUser) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: MedicalSourcesWidget(
                          medicationName: '',
                          isAiResponse: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
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
                                color: AppColors.primary, size: 18),
                          );
                        }
                        return Image.asset(
                          avatarPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person,
                              color: AppColors.primary, size: 18),
                        );
                      }
                      return const Icon(Icons.person,
                          color: AppColors.primary, size: 18);
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
        isConsultation ? const Color(0xFF10B981) : AppColors.primary;
    final hintKey =
        isConsultation ? 'consultationPlaceholder' : 'chatPlaceholder';

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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(left: 18, right: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Icon(
                        isConsultation
                            ? Icons.medical_services_outlined
                            : Icons.chat_bubble_outline_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: AppTextStyles.body(
                                isDark: isDark, fontWeight: FontWeight.w400)
                            .copyWith(fontSize: 15),
                        cursorColor: accentColor,
                        decoration: InputDecoration(
                          hintText: ref.t(hintKey),
                          hintStyle: AppTextStyles.small(isDark: isDark).copyWith(
                            color: isDark
                                ? AppColors.textMutedDark
                                : const Color(0xFF94A3B8),
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _sending ? 0.4 : 1.0,
                      child: GestureDetector(
                        onTap: _sending ? null : _handleSend,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 5, top: 5),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isConsultation
                                  ? [
                                      const Color(0xFF10B981),
                                      const Color(0xFF059669),
                                    ]
                                  : [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF6366F1),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Suggestion Item ──────────────────────────────────────────────────────

  Widget _buildSuggestionItem(String text, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          _messageController.text = text;
          _handleSend();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0x1AFFFFFF)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.small(isDark: isDark)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: isDark
                    ? AppColors.textMutedDark
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
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
