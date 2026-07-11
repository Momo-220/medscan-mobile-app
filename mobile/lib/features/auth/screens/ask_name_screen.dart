import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';

class AskNamePage extends ConsumerStatefulWidget {
  const AskNamePage({super.key});

  @override
  ConsumerState<AskNamePage> createState() => _AskNamePageState();
}

class _AskNamePageState extends ConsumerState<AskNamePage> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateInput);
    // Auto focus the input after layout builds (matching React autofocus)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _validateInput() {
    final trimmed = _nameController.text.trim();
    setState(() {
      _isValid = trimmed.length >= 2;
    });
  }

  Future<void> _handleSubmit() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.length < 2) return;

    final prefs = ref.read(sharedPrefsServiceProvider);
    await prefs.setLocalName(trimmed);
    
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Question Title
                Text(
                  ref.t('askNameTitle'),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Inline-like Borderless Blue Text Field
                TextField(
                  controller: _nameController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  cursorColor: AppColors.primary,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSubmit(),
                  decoration: InputDecoration(
                    hintText: '...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 48),

                // Continue Button
                Button(
                  disabled: !_isValid,
                  width: double.infinity,
                  onTap: _handleSubmit,
                  child: Text(ref.t('askNameButton')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
