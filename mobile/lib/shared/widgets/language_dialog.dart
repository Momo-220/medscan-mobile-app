import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/localization.dart';

const List<Map<String, String>> kSupportedLanguages = [
  {
    'code': 'fr',
    'label': 'Français',
    'sub': 'French',
    'flag': '🇫🇷',
  },
  {
    'code': 'en',
    'label': 'English',
    'sub': 'Anglais',
    'flag': '🇺🇸',
  },
  {
    'code': 'ar',
    'label': 'العربية',
    'sub': 'Arabe • Arabic',
    'flag': '🇦🇪',
  },
  {
    'code': 'tr',
    'label': 'Türkçe',
    'sub': 'Turc • Turkish',
    'flag': '🇹🇷',
  },
];

Future<void> showLanguageSelectionDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => LanguageSelectionDialog(isDark: isDark),
  );
}

class LanguageSelectionDialog extends ConsumerStatefulWidget {
  final bool isDark;

  const LanguageSelectionDialog({super.key, required this.isDark});

  @override
  ConsumerState<LanguageSelectionDialog> createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends ConsumerState<LanguageSelectionDialog> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = ref.read(languageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final currentLang = _selectedCode ?? ref.watch(languageProvider);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Title + Subtitle + Close icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.t('language'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sélectionnez votre langue d\'utilisation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Language options list
              ...kSupportedLanguages.map((lang) {
                final isSelected = currentLang == lang['code'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCode = lang['code'];
                      });
                      await ref.read(languageProvider.notifier).setLanguage(lang['code']!);
                      await Future.delayed(const Duration(milliseconds: 200));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? const Color(0xFF00ACC1).withValues(alpha: 0.16)
                                : const Color(0xFFE0F7FA))
                            : (isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.55)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF26C6DA)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircularFlagBadge(code: lang['code']!, size: 40.0),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lang['label']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang['sub']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF26C6DA) : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF26C6DA)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : const Color(0xFFCBD5E1)),
                                width: isSelected ? 2.0 : 1.6,
                              ),
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class CircularFlagBadge extends StatelessWidget {
  final String code;
  final double size;

  const CircularFlagBadge({super.key, required this.code, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: FlagCustomPainter(code),
        ),
      ),
    );
  }
}

class FlagCustomPainter extends CustomPainter {
  final String code;

  FlagCustomPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    switch (code.toLowerCase()) {
      case 'en':
      case 'us':
        // US Flag: 13 stripes
        final stripeHeight = size.height / 13;
        for (int i = 0; i < 13; i++) {
          paint.color = (i % 2 == 0) ? const Color(0xFFB22234) : const Color(0xFFFFFFFF);
          canvas.drawRect(Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight), paint);
        }
        // Navy blue canton
        final cantonWidth = size.width * 0.48;
        final cantonHeight = stripeHeight * 7;
        paint.color = const Color(0xFF3C3B6E);
        canvas.drawRect(Rect.fromLTWH(0, 0, cantonWidth, cantonHeight), paint);
        // Star dots
        paint.color = Colors.white;
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 4; c++) {
            final x = (c + 1) * (cantonWidth / 5);
            final y = (r + 1) * (cantonHeight / 4);
            canvas.drawCircle(Offset(x, y), 1.2, paint);
          }
        }
        break;

      case 'fr':
        // France Tricolore (Blue, White, Red)
        final w3 = size.width / 3;
        paint.color = const Color(0xFF002395);
        canvas.drawRect(Rect.fromLTWH(0, 0, w3, size.height), paint);
        paint.color = const Color(0xFFFFFFFF);
        canvas.drawRect(Rect.fromLTWH(w3, 0, w3, size.height), paint);
        paint.color = const Color(0xFFED2939);
        canvas.drawRect(Rect.fromLTWH(2 * w3, 0, w3, size.height), paint);
        break;

      case 'ar':
      case 'ae':
        // UAE Flag (Red vertical bar on left, Green, White, Black horizontal)
        final redWidth = size.width * 0.28;
        final remWidth = size.width - redWidth;
        final h3 = size.height / 3;
        // Top Green
        paint.color = const Color(0xFF00732F);
        canvas.drawRect(Rect.fromLTWH(redWidth, 0, remWidth, h3), paint);
        // Middle White
        paint.color = const Color(0xFFFFFFFF);
        canvas.drawRect(Rect.fromLTWH(redWidth, h3, remWidth, h3), paint);
        // Bottom Black
        paint.color = const Color(0xFF000000);
        canvas.drawRect(Rect.fromLTWH(redWidth, 2 * h3, remWidth, h3), paint);
        // Left Red
        paint.color = const Color(0xFFFF0000);
        canvas.drawRect(Rect.fromLTWH(0, 0, redWidth, size.height), paint);
        break;

      case 'tr':
        // Turkey Flag (Red with white crescent & star)
        paint.color = const Color(0xFFE30A17);
        canvas.drawRect(rect, paint);
        // Crescent outer white circle
        paint.color = Colors.white;
        canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.5), size.width * 0.25, paint);
        // Crescent cutout red circle
        paint.color = const Color(0xFFE30A17);
        canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.5), size.width * 0.20, paint);
        // 5-point star
        paint.color = Colors.white;
        _drawStar(
          canvas,
          Offset(size.width * 0.68, size.height * 0.5),
          size.width * 0.08,
          size.width * 0.035,
          paint,
        );
        break;

      default:
        paint.color = const Color(0xFFE2E8F0);
        canvas.drawRect(rect, paint);
        break;
    }

    // Outer subtle border
    paint.color = Colors.black.withValues(alpha: 0.10);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.8;
    canvas.drawOval(rect, paint);

    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double outerR, double innerR, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = (i % 2 == 0) ? outerR : innerR;
      final angle = (i * 36 - 90) * math.pi / 180;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FlagCustomPainter oldDelegate) => oldDelegate.code != code;
}
