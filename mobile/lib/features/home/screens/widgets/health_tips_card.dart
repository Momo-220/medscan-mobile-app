import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../reminders/providers/reminders_provider.dart';
import '../../../../data/models/reminder.dart';

class HealthTipsCardWidget extends ConsumerStatefulWidget {
  const HealthTipsCardWidget({super.key});

  @override
  ConsumerState<HealthTipsCardWidget> createState() => _HealthTipsCardWidgetState();
}

class _HealthTipsCardWidgetState extends ConsumerState<HealthTipsCardWidget> {
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  Reminder? _nextReminder;
  bool _loadingReminder = true;

  final List<Map<String, dynamic>> _allTips = [
    {
      'icon': '💧',
      'title': {
        'en': 'Hydration',
        'fr': 'Hydratation',
        'tr': 'Hydratation', // Matches screenshot fallback
        'ar': 'الترطيب',
      },
      'description': {
        'en': 'Drink a large glass of water with your medications to facilitate absorption',
        'fr': 'Buvez un grand verre d\'eau avec vos médicaments pour faciliter l\'absorption',
        'tr': 'Buvez un grand verre d\'eau avec vos médicaments pour faciliter l\'absorption', // Matches screenshot fallback
        'ar': 'اشرب كوبًا كبيرًا من الماء مع أدويتك لتسهيل امتصاصها',
      }
    },
    {
      'icon': '⏰',
      'title': {
        'en': 'Optimal timing',
        'fr': 'Timing optimal',
        'tr': 'Optimal zamanlama',
        'ar': 'التوقيت الأمثل',
      },
      'description': {
        'en': 'Take your medications at fixed times to maintain a constant level',
        'fr': 'Prenez vos médicaments à heures fixes pour maintenir un niveau constant',
        'tr': 'Sabit bir seviyeyi korumak için ilaçlarınızı sabit saatlerde alın',
        'ar': 'تناول أدويتك في أوقات ثابتة للحفاظ على مستوى ثابت في الجسم',
      }
    },
    {
      'icon': '🌡️',
      'title': {
        'en': 'Storage',
        'fr': 'Conservation',
        'tr': 'Saklama Koşulları',
        'ar': 'التخزين',
      },
      'description': {
        'en': 'Keep your medications away from light and moisture',
        'fr': 'Conservez vos médicaments à l\'abri de la lumière et de l\'humidité',
        'tr': 'İlaçlarınızı ışık ve nemden uzak tutun',
        'ar': 'احفظ أدويتك بعيدًا عن الضوء والرطوبة',
      }
    },
    {
      'icon': '⚠️',
      'title': {
        'en': 'Interactions',
        'fr': 'Interactions',
        'tr': 'Etkileşimler',
        'ar': 'التفاعلات الدوائية',
      },
      'description': {
        'en': 'Avoid alcohol and grapefruit with most medications',
        'fr': 'Évitez l\'alcool et le pamplemousse avec la plupart des médicaments',
        'tr': 'Çoğu ilaçla birlikte alkol ve greyfurt tüketmekten kaçının',
        'ar': 'تجنب تناول الكحول والجريب فروت مع معظم الأدوية',
      }
    },
    {
      'icon': '📅',
      'title': {
        'en': 'Expiration',
        'fr': 'Péremption',
        'tr': 'Son Kullanma Tarihi',
        'ar': 'تاريخ الصلاحية',
      },
      'description': {
        'en': 'Always check the expiration date before taking a medication',
        'fr': 'Vérifiez toujours la date de péremption avant de prendre un médicament',
        'tr': 'Bir ilacı almadan önce daima son kullanma tarihini kontrol edin',
        'ar': 'تحقق دائمًا من تاريخ انتهاء الصلاحية قبل تناول أي دواء',
      }
    }
  ];

  @override
  void initState() {
    super.initState();
    _startTipRotation();
    _loadNextReminder();
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipRotation() {
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _allTips.length;
        });
      }
    });
  }

  Future<void> _loadNextReminder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _nextReminder = null;
          _loadingReminder = false;
        });
      }
      return;
    }

    try {
      // Accessing reminders via Riverpod notifier
      final remindersAsync = ref.read(remindersProvider);
      remindersAsync.when(
        data: (reminders) {
          final activeReminders = reminders.where((r) => r.active).toList();
          if (activeReminders.isNotEmpty) {
            // Sort by next dose date
            activeReminders.sort((a, b) => a.nextDose.compareTo(b.nextDose));
            if (mounted) {
              setState(() {
                _nextReminder = activeReminders.first;
                _loadingReminder = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _nextReminder = null;
                _loadingReminder = false;
              });
            }
          }
        },
        error: (_, __) {
          if (mounted) {
            setState(() {
              _nextReminder = null;
              _loadingReminder = false;
            });
          }
        },
        loading: () {
          // Keep loading state
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _nextReminder = null;
          _loadingReminder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Auto-listen to reminders changes to refresh next reminder card
    ref.listen(remindersProvider, (previous, next) {
      _loadNextReminder();
    });

    final String langCode = ref.read(languageProvider);

    final tip = _allTips[_currentTipIndex];
    final String tipTitle = tip['title'][langCode] ?? tip['title']['fr'];
    final String tipDesc = tip['description'][langCode] ?? tip['description']['fr'];
    final String tipIcon = tip['icon'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // 1. Next Reminder Section (Pill Blue Theme Card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF1E3A8A).withOpacity(0.2), const Color(0xFF1E40AF).withOpacity(0.1)]
                    : [AppColors.primary.withOpacity(0.12), AppColors.primary.withOpacity(0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF1E40AF).withOpacity(0.3) : AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.4) : AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.notifications_none_outlined,
                    color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.t('nextReminderTitle'),
                        style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_loadingReminder)
                        const Skeleton(height: 16, width: 120)
                      else if (_nextReminder != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nextReminder!.medicationName,
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        _nextReminder!.time,
                                        style: AppTextStyles.micro(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_nextReminder!.dosage.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.medication_outlined, size: 12, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          _nextReminder!.dosage,
                                          style: AppTextStyles.micro(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      else
                        Text(
                          ref.t('noReminderScheduled'),
                          style: AppTextStyles.small(
                            color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Health Tip Section (Emerald Green Card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF065F46).withOpacity(0.2), const Color(0xFF064E3B).withOpacity(0.1)]
                    : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5).withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF047857).withOpacity(0.3) : const Color(0xFFA7F3D0).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF065F46).withOpacity(0.4) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tipIcon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                ref.t('healthTip'),
                                style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                  fontSize: 14,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tipTitle,
                            style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tipDesc,
                            style: AppTextStyles.small(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ).copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Divider and page progress indicator
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF047857).withOpacity(0.2) : const Color(0xFFA7F3D0).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots
                      Row(
                        children: List.generate(_allTips.length, (idx) {
                          final isActive = idx == _currentTipIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 4),
                            height: 5,
                            width: isActive ? 20 : 5,
                            decoration: BoxDecoration(
                              color: isActive 
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
                                  : (isDark ? const Color(0xFF064E3B) : const Color(0xFFA7F3D0)),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          );
                        }),
                      ),
                      // Fraction text
                      Text(
                        '${_currentTipIndex + 1}/${_allTips.length}',
                        style: AppTextStyles.micro(isDark: isDark).copyWith(
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
