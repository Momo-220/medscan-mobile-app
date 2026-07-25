import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../data/models/app_version.dart';

class VersionUpdateDialog extends StatelessWidget {
  final AppVersionModel config;
  final bool isForceUpdate;

  const VersionUpdateDialog({
    super.key,
    required this.config,
    required this.isForceUpdate,
  });

  Future<void> _launchStore(BuildContext context) async {
    String urlString = Platform.isIOS ? config.appStoreUrl : config.playStoreUrl;
    
    // Fallback if URL in Firestore config is empty
    if (urlString.trim().isEmpty) {
      if (Platform.isIOS) {
        urlString = 'https://apps.apple.com/app/id6742562145';
      } else {
        urlString = 'https://play.google.com/store/apps/details?id=com.seinimomo.medscanapp';
      }
    }

    try {
      final uri = Uri.parse(urlString.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      debugPrint('Could not launch store URL: $e');
      try {
        final uri = Uri.parse(urlString.trim());
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dialogContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clean, modern, minimalist header icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.system_update_rounded,
                color: Color(0xFF3B82F6),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Simple Title
          Text(
            isForceUpdate ? 'Mise à jour requise' : 'Mise à jour disponible',
            style: AppTextStyles.h2(isDark: isDark).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Simple Body text
          Text(
            isForceUpdate
                ? 'Veuillez mettre à jour MedScan pour pouvoir continuer à utiliser l\'application.'
                : 'Veuillez mettre à jour votre application MedScan pour bénéficier des dernières améliorations.',
            style: AppTextStyles.small(isDark: isDark).copyWith(
              height: 1.45,
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              if (!isForceUpdate) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Plus tard',
                      style: AppTextStyles.smallBold(isDark: isDark).copyWith(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _launchStore(context),
                  child: const Text(
                    'Mettre à jour',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !isForceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: dialogContent,
      ),
    );
  }
}

class MaintenanceDialog extends StatelessWidget {
  final String message;

  const MaintenanceDialog({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dialogContent = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.construction_rounded,
                color: Colors.orange,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Maintenance en cours',
            style: AppTextStyles.h2(isDark: isDark).copyWith(fontWeight: FontWeight.bold, fontSize: 19),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty
                ? message
                : 'MedScan est actuellement en cours de maintenance. Veuillez réessayer plus tard.',
            style: AppTextStyles.small(isDark: isDark).copyWith(
              height: 1.45,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: dialogContent,
      ),
    );
  }
}
