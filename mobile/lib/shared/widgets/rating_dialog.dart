 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../services/review_service.dart';
import '../utils/localization.dart';

class RatingDialog extends ConsumerStatefulWidget {
  const RatingDialog({super.key});

  /// Convenient helper to display the rating dialog
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const RatingDialog(),
    );
  }

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  int _selectedRating = 0;
  bool _submittedRating = false;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSendingFeedback = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onStarTapped(int rating) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedRating = rating;
      _submittedRating = true;
    });
  }

  Future<void> _handleStoreReview() async {
    final reviewService = ref.read(reviewServiceProvider);
    Navigator.of(context).pop();
    await reviewService.requestStoreReview();
  }

  Future<void> _handleSendFeedback() async {
    setState(() {
      _isSendingFeedback = true;
    });

    final reviewService = ref.read(reviewServiceProvider);
    await reviewService.recordReviewCompleted();

    // Feedback can be logged / stored
    final text = _feedbackController.text.trim();
    if (text.isNotEmpty) {
      debugPrint('📝 In-App Feedback recorded: $_selectedRating stars - $text');
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.t('ratingFeedbackThanks')),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handlePostpone() async {
    final reviewService = ref.read(reviewServiceProvider);
    await reviewService.recordReviewPostponed();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.cardDark : AppColors.card;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 10,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // MedScan Logo centered at the top (no text)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.backgroundDark : AppColors.background,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 20),

              if (!_submittedRating) ...[
                // Initial Step: Rating with 5 stars
                Text(
                  ref.t('ratingTitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3(isDark: isDark),
                ),
                const SizedBox(height: 10),
                Text(
                  ref.t('ratingSubtitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    isDark: isDark,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 24),

                // 5 interactive stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    final isFilled = starIndex <= _selectedRating;
                    return GestureDetector(
                      onTap: () => _onStarTapped(starIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedScale(
                          scale: isFilled ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: isFilled ? const Color(0xFFFFB800) : AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // "Plus tard" button
                TextButton(
                  onPressed: _handlePostpone,
                  child: Text(
                    ref.t('ratingLater'),
                    style: AppTextStyles.body(
                      isDark: isDark,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ] else if (_selectedRating >= 4) ...[
                // Step 2A: 4 or 5 stars -> Promote Store review
                Text(
                  ref.t('ratingStorePromptTitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3(isDark: isDark),
                ),
                const SizedBox(height: 10),
                Text(
                  ref.t('ratingStorePromptSubtitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    isDark: isDark,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Button to rate on store
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleStoreReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          ref.t('ratingRateOnStore'),
                          style: AppTextStyles.bodySemiBold(color: Colors.white).copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: _handlePostpone,
                  child: Text(
                    ref.t('ratingLater'),
                    style: AppTextStyles.body(
                      isDark: isDark,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ).copyWith(fontSize: 14),
                  ),
                ),
              ] else ...[
                // Step 2B: 1 to 3 stars -> Internal feedback form
                Text(
                  ref.t('ratingFeedbackTitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3(isDark: isDark),
                ),
                const SizedBox(height: 8),
                Text(
                  ref.t('ratingFeedbackSubtitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    isDark: isDark,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  style: AppTextStyles.body(isDark: isDark).copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: ref.t('ratingFeedbackPlaceholder'),
                    hintStyle: AppTextStyles.body(
                      isDark: isDark,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ).copyWith(fontSize: 13),
                    filled: true,
                    fillColor: isDark ? AppColors.backgroundDark : AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSendingFeedback ? null : _handleSendFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSendingFeedback
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            ref.t('ratingSendFeedback'),
                            style: AppTextStyles.bodySemiBold(color: Colors.white).copyWith(fontSize: 15),
                          ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: _handlePostpone,
                  child: Text(
                    ref.t('ratingLater'),
                    style: AppTextStyles.body(
                      isDark: isDark,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ).copyWith(fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
