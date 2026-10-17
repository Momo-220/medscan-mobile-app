import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../shared/utils/localization.dart';
import '../../../reminders/providers/reminders_provider.dart';
import 'medication_reminders.dart';

class NextDoseCardWidget extends ConsumerStatefulWidget {
  const NextDoseCardWidget({super.key});

  @override
  ConsumerState<NextDoseCardWidget> createState() => _NextDoseCardWidgetState();
}

class _NextDoseCardWidgetState extends ConsumerState<NextDoseCardWidget> {
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  final List<Map<String, dynamic>> _tips = [
    {
      'icon': '💧',
      'title': {'fr': 'Hydratation', 'en': 'Hydration', 'tr': 'Sıvı Alımı', 'ar': 'الترطيب'},
      'desc': {
        'fr': 'Buvez un grand verre d\'eau avec vos médicaments.',
        'en': 'Drink a glass of water with your medication.',
        'tr': 'İlaçlarınızı bol su ile içiniz.',
        'ar': 'اشرب كوبًا كبيرًا من الماء مع دوائك.',
      },
    },
    {
      'icon': '⏰',
      'title': {'fr': 'Régularité', 'en': 'Timing', 'tr': 'Zamanlama', 'ar': 'التوقيت'},
      'desc': {
        'fr': 'Prenez vos comprimés à heures fixes chaque jour.',
        'en': 'Take your pills at regular times every day.',
        'tr': 'İlaçlarınızı her gün aynı saatte alın.',
        'ar': 'تناول أدويتك في أوقات منتظمة يوميًا.',
      },
    },
    {
      'icon': '🍽️',
      'title': {'fr': 'Repas', 'en': 'Meals', 'tr': 'Yemekler', 'ar': 'الوجبات'},
      'desc': {
        'fr': 'Vérifiez si la prise se fait avant ou après le repas.',
        'en': 'Check if doses should be taken before or after meals.',
        'tr': 'Yemekten önce mi sonra mı alınacağını kontrol edin.',
        'ar': 'تحقق مما إذا كان الدواء يؤخذ قبل أو بعد الوجبات.',
      },
    },
    {
      'icon': '🌡️',
      'title': {'fr': 'Conservation', 'en': 'Storage', 'tr': 'Saklama', 'ar': 'الحفظ'},
      'desc': {
        'fr': 'Conservez vos boîtes à l\'abri de l\'humidité et chaleur.',
        'en': 'Store your medicines away from heat and moisture.',
        'tr': 'İlaçları ısı ve nemden uzakta saklayın.',
        'ar': 'احفظ أدويتك بعيدًا عن الحرارة والرطوبة.',
      },
    },
    {
      'icon': '💊',
      'title': {'fr': 'Ne pas couper', 'en': 'Do not crush', 'tr': 'Kırmayınız', 'ar': 'لا تقسم'},
      'desc': {
        'fr': 'Certaines gélules ne doivent jamais être ouvertes.',
        'en': 'Some capsules must never be broken or opened.',
        'tr': 'Bazı kapsüller asla ezilmemeli veya kırılmamalıdır.',
        'ar': 'بعض الكبسولات يجب ألا تُكسر أو تُفتح أبدًا.',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
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

  void _showAllReminders(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MedicationRemindersWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remindersAsync = ref.watch(remindersProvider);
    final lang = ref.watch(languageProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // 1. LEFT CARD: Next Reminder (Soft Blue)
          Expanded(
            child: remindersAsync.when(
              loading: () => _buildReminderCard(
                context: context,
                isDark: isDark,
                title: ref.t('nextReminderTitle'),
                name: ref.t('loading'),
                time: '--:--',
                onTap: () => _showAllReminders(context, isDark),
              ),
              error: (_, __) => _buildReminderCard(
                context: context,
                isDark: isDark,
                title: ref.t('nextReminderTitle'),
                name: ref.t('noRemindersConfigured'),
                time: '+ ${ref.t('add')}',
                onTap: () => _showAllReminders(context, isDark),
              ),
              data: (reminders) {
                final active = reminders.where((r) => r.active).toList();
                if (active.isEmpty) {
                  return _buildReminderCard(
                    context: context,
                    isDark: isDark,
                    title: ref.t('nextReminderTitle'),
                    name: ref.t('noRemindersConfigured'),
                    time: '+ ${ref.t('add')}',
                    onTap: () => _showAllReminders(context, isDark),
                  );
                }
                active.sort((a, b) => a.nextDose.compareTo(b.nextDose));
                final next = active.first;
                final doseText = next.dosage.isNotEmpty ? next.dosage : '1 prise';
                final timeText = next.time;

                return _buildReminderCard(
                  context: context,
                  isDark: isDark,
                  title: ref.t('nextReminderTitle'),
                  name: next.medicationName,
                  time: '$doseText • $timeText',
                  onTap: () => _showAllReminders(context, isDark),
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // 2. RIGHT CARD: Health Tip (Soft Mint)
          Expanded(
            child: _buildHealthTipCard(context, isDark, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String name,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F2FD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFD4E6FA),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A3B5D).withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title + Clock Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),

            // Medication Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),

            // Time & Dosage
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTipCard(BuildContext context, bool isDark, String lang) {
    final tip = _tips[_currentTipIndex];
    final title = tip['title'][lang] ?? tip['title']['fr'] ?? 'Hydratation';
    final desc = tip['desc'][lang] ?? tip['desc']['fr'] ?? '';
    final icon = tip['icon'] as String;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F8EE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFD0F0DB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A3B5D).withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Health tip indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ref.t('healthTip')} : ${_currentTipIndex + 1}/${_tips.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                  ),
                ),
                Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                ),
              ],
            ),

            // Tip Body
            Text(
              '$icon $title - $desc',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF065F46),
                height: 1.25,
              ),
            ),

            // Pagination Dots Indicator (5 dots)
            Row(
              children: List.generate(_tips.length, (index) {
                final isActive = index == _currentTipIndex;
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: isActive ? 12 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive
                        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669))
                        : (isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFA7F3D0)),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
