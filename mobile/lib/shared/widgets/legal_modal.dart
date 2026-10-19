import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/colors.dart';
import 'button.dart';

class _LegalSection {
  final String? badge;
  final String title;
  final String body;

  const _LegalSection({
    this.badge,
    required this.title,
    required this.body,
  });
}

List<_LegalSection> _parseLegalSections(String content) {
  final blocks = content.split('\n\n').where((b) => b.trim().isNotEmpty).toList();
  final List<_LegalSection> sections = [];

  for (final block in blocks) {
    final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) continue;

    final firstLine = lines.first;
    final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(firstLine);
    if (match != null) {
      final numStr = match.group(1)!;
      final title = match.group(2)!.trim();
      final body = lines.length > 1 ? lines.sublist(1).join('\n\n') : '';
      sections.add(_LegalSection(
        badge: numStr.padLeft(2, '0'),
        title: title,
        body: body,
      ));
    } else {
      sections.add(_LegalSection(
        badge: null,
        title: firstLine,
        body: lines.length > 1 ? lines.sublist(1).join('\n\n') : '',
      ));
    }
  }

  return sections;
}

void showLegalModal(
  BuildContext context, {
  required String title,
  required String content,
  String closeLabel = 'Fermer',
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sections = _parseLegalSections(content);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Modal Header with Icon & Close Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'MedScan • Informations certifiées',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              ),

              // Scrollable Legal Sections Cards
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: sections.map((sec) {
                      final isEmergency = sec.body.contains('15') || sec.body.contains('112') || sec.title.toLowerCase().contains('urgence');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isEmergency
                              ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.25) : const Color(0xFFFEF2F2))
                              : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isEmergency
                                ? (isDark ? Colors.red.withValues(alpha: 0.4) : const Color(0xFFFCA5A5))
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (sec.badge != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isEmergency
                                          ? Colors.red.withValues(alpha: 0.15)
                                          : const Color(0xFF2563EB).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      sec.badge!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isEmergency ? Colors.red : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    sec.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: isEmergency
                                          ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sec.body.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                sec.body,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: isEmergency
                                      ? (isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D))
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Bottom Pill CTA Button (En pilule comme demandé)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Button(
                  width: double.infinity,
                  size: ButtonSize.md,
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(closeLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
