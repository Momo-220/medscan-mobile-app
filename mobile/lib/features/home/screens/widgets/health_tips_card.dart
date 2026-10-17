import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/utils/localization.dart';

class HealthTipsCardWidget extends ConsumerStatefulWidget {
  const HealthTipsCardWidget({super.key});

  @override
  ConsumerState<HealthTipsCardWidget> createState() => _HealthTipsCardWidgetState();
}

class _HealthTipsCardWidgetState extends ConsumerState<HealthTipsCardWidget> {
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  final List<Map<String, dynamic>> _tips = [
    {
      'icon': '💧',
      'title': {'fr': 'Hydratation', 'en': 'Hydration', 'tr': 'Sıvı Alımı', 'ar': 'الترطيب'},
      'desc': {
        'fr': 'Buvez un grand verre d\'eau avec vos médicaments pour faciliter l\'absorption.',
        'en': 'Drink a large glass of water with your medications to facilitate absorption.',
        'tr': 'İlaçlarınızın emilimini kolaylaştırmak için bol su ile alınız.',
        'ar': 'اشرب كوبًا كبيرًا من الماء مع دوائك لتسهيل امتصاصه.',
      },
    },
    {
      'icon': '⏰',
      'title': {'fr': 'Régularité', 'en': 'Timing', 'tr': 'Zamanlama', 'ar': 'التوقيت'},
      'desc': {
        'fr': 'Prenez vos comprimés à heures fixes pour maintenir un niveau d\'efficacité stable.',
        'en': 'Take your pills at regular hours to maintain stable effectiveness.',
        'tr': 'İlaçlarınızı sabit saatlerde alarak etkinliğini koruyun.',
        'ar': 'تناول أدويتك في أوقات منتظمة للحفاظ على فعاليتها.',
      },
    },
    {
      'icon': '🍽️',
      'title': {'fr': 'Repas', 'en': 'Meals', 'tr': 'Yemekler', 'ar': 'الوجبات'},
      'desc': {
        'fr': 'Vérifiez toujours si la prise se fait avant, pendant ou après le repas.',
        'en': 'Check if doses should be taken before, during, or after meals.',
        'tr': 'Yemekten önce mi, sırasında mı, sonra mı alınacağını kontrol edin.',
        'ar': 'تحقق مما إذا كان الدواء يؤخذ قبل أو أثناء أو بعد الوجبات.',
      },
    },
    {
      'icon': '🌡️',
      'title': {'fr': 'Conservation', 'en': 'Storage', 'tr': 'Saklama', 'ar': 'الحفظ'},
      'desc': {
        'fr': 'Conservez vos boîtes à l\'abri de l\'humidité, de la lumière et de la chaleur.',
        'en': 'Store your medications away from humidity, light, and heat.',
        'tr': 'İlaçlarınızı nem, ışık ve sıcaktan uzakta muhafaza ediniz.',
        'ar': 'احفظ أدويتك بعيدًا عن الرطوبة والضوء والحرارة.',
      },
    },
    {
      'icon': '💊',
      'title': {'fr': 'Ne pas couper', 'en': 'Do not crush', 'tr': 'Kırmayınız', 'ar': 'لا تقسم'},
      'desc': {
        'fr': 'Certaines gélules et comprimés à libération prolongée ne doivent jamais être broyés.',
        'en': 'Certain extended-release capsules and tablets must never be crushed.',
        'tr': 'Bazı uzun etkili kapsüller asla kırılmamalı veya ezilmemelidir.',
        'ar': 'بعض الكبسولات ممتدة المفعول يجب عدم كسرها أو طحنها أبدًا.',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String lang = ref.watch(languageProvider);
    final tip = _tips[_currentTipIndex];
    final String title = tip['title'][lang] ?? tip['title']['fr'];
    final String desc = tip['desc'][lang] ?? tip['desc']['fr'];
    final String icon = tip['icon'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
          });
          _startTimer();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF064E3B).withOpacity(0.20)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF10B981).withOpacity(0.25)
                  : const Color(0xFF86EFAC).withOpacity(0.60),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Label + Count + Sparkles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF10B981).withOpacity(0.18)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${ref.t('healthTip')} : ${_currentTipIndex + 1}/${_tips.length}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Animated content with zero ghosting/overlap
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                layoutBuilder: (currentChild, previousChildren) =>
                    currentChild ?? const SizedBox.shrink(),
                child: Row(
                  key: ValueKey<int>(_currentTipIndex),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.35,
                            color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B),
                          ),
                          children: [
                            TextSpan(
                              text: '$title – ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: desc,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Bottom Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_tips.length, (idx) {
                  final bool active = idx == _currentTipIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: active ? 16 : 5,
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
                          : (isDark ? Colors.white.withOpacity(0.15) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
