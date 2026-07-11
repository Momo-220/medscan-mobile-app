import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../providers/chat_provider.dart';
import '../../home/providers/credits_provider.dart';
import '../../../shared/utils/pill_notification.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Auto scroll to bottom when keyboard opens or list loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    
    final bottomOffset = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        bottomOffset + 100, // Extra padding to scroll past the keyboard
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(bottomOffset);
    }
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    _messageController.clear();
    setState(() {
      _sending = true;
    });

    final langCode = ref.read(languageProvider);

    try {
      // Trigger scroll to bottom for the placeholder message
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      await ref.read(chatProvider.notifier).sendMessage(text, langCode);
      
      setState(() {
        _sending = false;
      });
      
      // Scroll to bottom once streaming starts/finishes
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      setState(() {
        _sending = false;
      });

      if (e.toString().contains('INSUFFICIENT_CREDITS') && mounted) {
        _showCreditsDialog(context);
      } else if (mounted) {
        showPillError(context, ref.t('chatError'));
      }
    }
  }

  void _showCreditsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
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
                Text(
                  ref.t('insufficientCredits'),
                  style: AppTextStyles.h3(isDark: isDark),
                ),
                const SizedBox(height: 12),
                Text(
                  isAnonymous
                      ? ref.t('trialOrSignInTagline')
                      : ref.t('chatNoGems'),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatProvider);

    // Auto scroll when streaming updates (state changes)
    ref.listen(chatProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/images/doctor-png.jpg'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        ref.t('doctorName'),
                        style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 15),
                      ),
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
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ref.t('online'),
                        style: AppTextStyles.micro(isDark: isDark).copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ref.t('respondsQuickly'),
                        style: AppTextStyles.micro(isDark: isDark).copyWith(
                          color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Medical Disclaimer Header Badge
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B).withOpacity(0.8), const Color(0xFF0F172A).withOpacity(0.8)]
                      : [const Color(0xFFEFF6FF).withOpacity(0.9), const Color(0xFFDBEAFE).withOpacity(0.9)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFBFDBFE),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ref.t('disclaimerMedical'),
                      style: AppTextStyles.micro(isDark: isDark).copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Chat messages viewport list
            Expanded(
              child: chatState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      ref.t('chatError'),
                      style: AppTextStyles.small(isDark: isDark),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                                        border: Border.all(color: isDark ? AppColors.cardDark : Colors.white, width: 2.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  ref.t('doctorGreeting'),
                                  style: AppTextStyles.h2(isDark: isDark).copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  ref.t('doctorDescription'),
                                  style: AppTextStyles.small(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                  ).copyWith(height: 1.5, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Suggestions title
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              ref.t('frequentlyAskedQuestions'),
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // FAQ list
                          _buildSuggestionItem(ref.t('faqQuestion1')),
                          _buildSuggestionItem(ref.t('faqQuestion2')),
                          _buildSuggestionItem(ref.t('faqQuestion3')),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
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
                              // Assistant Avatar
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Message Bubble
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? AppColors.primary
                                      : (isDark ? AppColors.cardDark : Colors.white),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isUser ? 20 : 0),
                                    bottomRight: Radius.circular(isUser ? 0 : 20),
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
                                    ? Text(
                                        msg.content,
                                        style: AppTextStyles.small(isDark: false)
                                            .copyWith(color: Colors.white),
                                      )
                                    : (index == messages.length - 1
                                        ? TypingMarkdown(
                                            data: msg.content,
                                            isDark: isDark,
                                            onCharacterTyped: _scrollToBottom,
                                          )
                                        : MarkdownBody(
                                            data: msg.content,
                                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                              p: AppTextStyles.small(isDark: isDark).copyWith(height: 1.5),
                                              listBullet: AppTextStyles.small(isDark: isDark),
                                            ),
                                          )),
                              ),
                            ),

                            if (isUser) ...[
                              const SizedBox(width: 8),
                              // User Avatar
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardDark : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 3. Bottom Text Input bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(left: 20, right: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: AppTextStyles.body(isDark: isDark, fontWeight: FontWeight.w400)
                                  .copyWith(fontSize: 15),
                              cursorColor: AppColors.primary,
                              decoration: InputDecoration(
                                hintText: ref.t('chatPlaceholder'),
                                hintStyle: AppTextStyles.small(isDark: isDark).copyWith(
                                  color: isDark ? AppColors.textMutedDark : const Color(0xFF94A3B8),
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onSubmitted: (_) => _handleSend(),
                            ),
                          ),
                          if (_sending)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _handleSend,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)], // Blue to Indigo gradient
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
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
            
            // Padding buffer for safe nav bar spacing
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(String text) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
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
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.small(isDark: isDark).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TypingMarkdown extends StatefulWidget {
  final String data;
  final bool isDark;
  final VoidCallback? onCharacterTyped;

  const TypingMarkdown({
    super.key,
    required this.data,
    required this.isDark,
    this.onCharacterTyped,
  });

  @override
  State<TypingMarkdown> createState() => _TypingMarkdownState();
}

class _TypingMarkdownState extends State<TypingMarkdown> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant TypingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _startTyping();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (_currentIndex < widget.data.length) {
        setState(() {
          _currentIndex++;
          _displayedText = widget.data.substring(0, _currentIndex);
        });
        if (widget.onCharacterTyped != null) {
          widget.onCharacterTyped!();
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textToDisplay = _displayedText.isEmpty && widget.data.isNotEmpty
        ? widget.data
        : (_displayedText.isEmpty ? 'Typing...' : _displayedText);

    return MarkdownBody(
      data: textToDisplay,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: AppTextStyles.small(isDark: widget.isDark).copyWith(height: 1.5),
        listBullet: AppTextStyles.small(isDark: widget.isDark),
      ),
    );
  }
}
