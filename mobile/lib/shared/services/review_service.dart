import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../core/di/providers.dart';
import '../../data/local/shared_prefs.dart';

class ReviewService {
  final SharedPrefsService _prefs;
  final InAppReview _inAppReview = InAppReview.instance;

  ReviewService(this._prefs);

  // Constants
  static const int minTotalScansRequired = 2;
  static const int postponeDurationDays = 20;

  // iOS App Store ID (can be set to MedScan Apple ID when assigned)
  static const String appStoreId = ''; 

  /// Check if the user is eligible for a review prompt.
  /// [existingPharmacyCount] provides the number of already saved medications
  /// in the pharmacy (useful for returning users after an app update).
  bool shouldPromptForReview({int existingPharmacyCount = 0}) {
    // 1. If already rated or explicitly declined, never prompt again
    if (_prefs.hasRatedApp()) {
      return false;
    }

    // 2. Check total scans (scans recorded by counter + existing scans in history)
    final recordedScans = _prefs.getSuccessfulScansCount();
    final totalScans = recordedScans + existingPharmacyCount;
    if (totalScans < minTotalScansRequired) {
      return false;
    }

    // 3. Check if postponed recently (at least 20 days interval)
    final lastPromptTs = _prefs.getLastRatingPromptTimestamp();
    if (lastPromptTs != null) {
      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptTs);
      final daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
      if (daysSinceLastPrompt < postponeDurationDays) {
        return false;
      }
    }

    return true;
  }

  /// Call this when a scan completes successfully
  Future<void> onScanSuccessful() async {
    await _prefs.incrementSuccessfulScansCount();
  }

  /// Mark review as completed (after rating or internal feedback)
  Future<void> recordReviewCompleted() async {
    await _prefs.setHasRatedApp(true);
  }

  /// Mark review as postponed ("Plus tard")
  Future<void> recordReviewPostponed() async {
    await _prefs.setLastRatingPromptTimestamp(DateTime.now().millisecondsSinceEpoch);
  }

  /// Trigger the official in-app review or redirect to store listing
  Future<void> requestStoreReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable && !kIsWeb) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing(
          appStoreId: appStoreId.isNotEmpty ? appStoreId : null,
        );
      }
    } catch (e) {
      debugPrint('🚨 ReviewService error: $e');
      try {
        await _inAppReview.openStoreListing(
          appStoreId: appStoreId.isNotEmpty ? appStoreId : null,
        );
      } catch (inner) {
        debugPrint('🚨 Fallback openStoreListing error: $inner');
      }
    } finally {
      await recordReviewCompleted();
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>((ref) {
  final prefs = ref.watch(sharedPrefsServiceProvider);
  return ReviewService(prefs);
});
