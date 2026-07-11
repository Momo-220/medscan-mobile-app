import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/button.dart';
import '../../../../shared/widgets/card.dart';
import '../../../../shared/widgets/input.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../reminders/providers/reminders_provider.dart';
import '../../../../data/models/reminder.dart';
import '../../../../shared/utils/pill_notification.dart';
class MedicationRemindersWidget extends ConsumerStatefulWidget {
  const MedicationRemindersWidget({super.key});

  @override
  ConsumerState<MedicationRemindersWidget> createState() => _MedicationRemindersWidgetState();
}

class _MedicationRemindersWidgetState extends ConsumerState<MedicationRemindersWidget> {
  void _showAddEditReminderDialog(BuildContext context, {Reminder? reminder}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = reminder != null;

    final nameController = TextEditingController(text: reminder?.medicationName ?? '');
    final dosageController = TextEditingController(text: reminder?.dosage ?? '');
    
    // Default time parsing
    String selectedTime = reminder?.time ?? '08:00';
    final initialParts = selectedTime.split(':');
    TimeOfDay timeOfDay = TimeOfDay(
      hour: int.parse(initialParts[0]),
      minute: int.parse(initialParts[1]),
    );

    String selectedFrequency = reminder?.frequency ?? 'daily';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? ref.t('editReminder') : ref.t('addReminder'),
                      style: AppTextStyles.h3(isDark: isDark),
                    ),
                    const SizedBox(height: 20),

                    // Medication Name Input
                    Text(ref.t('medicationName'), style: AppTextStyles.smallBold(isDark: isDark)),
                    const SizedBox(height: 6),
                    CustomInput(
                      controller: nameController,
                      hintText: 'Ex: Paracétamol',
                    ),
                    const SizedBox(height: 16),

                    // Dosage Input
                    Text(ref.t('dosage'), style: AppTextStyles.smallBold(isDark: isDark)),
                    const SizedBox(height: 6),
                    CustomInput(
                      controller: dosageController,
                      hintText: 'Ex: 1 comprimé',
                    ),
                    const SizedBox(height: 16),

                    // Time Selector Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.t('time'), style: AppTextStyles.smallBold(isDark: isDark)),
                            const SizedBox(height: 6),
                            Text(
                              selectedTime,
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 20, color: AppColors.primary),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: timeOfDay,
                              builder: (context, child) {
                                return Theme(
                                  data: isDark ? ThemeData.dark() : ThemeData.light(),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setDialogState(() {
                                timeOfDay = picked;
                                final hour = picked.hour.toString().padLeft(2, '0');
                                final min = picked.minute.toString().padLeft(2, '0');
                                selectedTime = '$hour:$min';
                              });
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(ref.t('edit')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Frequency Selector
                    Text(ref.t('frequency'), style: AppTextStyles.smallBold(isDark: isDark)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFrequency,
                          dropdownColor: isDark ? AppColors.cardDark : AppColors.card,
                          style: AppTextStyles.small(isDark: isDark),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedFrequency = val;
                              });
                            }
                          },
                          items: [
                            DropdownMenuItem(value: 'daily', child: Text(ref.t('daily'))),
                            DropdownMenuItem(value: 'twice', child: Text(ref.t('twice'))),
                            DropdownMenuItem(value: 'three-times', child: Text(ref.t('threeTimes'))),
                            DropdownMenuItem(value: 'custom', child: Text(ref.t('custom'))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(ref.t('close'), style: AppTextStyles.small(color: AppColors.textMuted)),
                        ),
                        const SizedBox(width: 12),
                        Button(
                          onTap: () async {
                            final name = nameController.text.trim();
                            final dosage = dosageController.text.trim();

                            if (name.isEmpty || dosage.isEmpty) return;

                            try {
                              if (isEdit) {
                                await ref.read(remindersProvider.notifier).updateReminder(
                                      id: reminder.id,
                                      medicationName: name,
                                      dosage: dosage,
                                      time: selectedTime,
                                      frequency: selectedFrequency,
                                      active: reminder.active,
                                    );
                              } else {
                                await ref.read(remindersProvider.notifier).addReminder(
                                      medicationName: name,
                                      dosage: dosage,
                                      time: selectedTime,
                                      frequency: selectedFrequency,
                                    );
                              }
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {}
                          },
                          child: Text(isEdit ? ref.t('edit') : ref.t('create')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ref.t('deleteReminder'), style: AppTextStyles.h3(isDark: isDark)),
          content: Text(
            ref.t('confirmDeleteReminder'),
            style: AppTextStyles.small(isDark: isDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ref.t('close'), style: AppTextStyles.small(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(remindersProvider.notifier).deleteReminder(id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                'Supprimer',
                style: AppTextStyles.smallBold().copyWith(color: Colors.red[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remindersAsync = ref.watch(remindersProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Reminders module
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.t('medicationRemindersTitle'),
                style: AppTextStyles.h3(isDark: isDark),
              ),
              if (!isAnonymous)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                  onPressed: () => _showAddEditReminderDialog(context),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (isAnonymous)
            _buildTrialCard(isDark)
          else
            remindersAsync.when(
              loading: () => _buildSkeletonList(),
              error: (err, stack) => const SizedBox(),
              data: (reminders) {
                if (reminders.isEmpty) {
                  return _buildEmptyCard(isDark);
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reminders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final r = reminders[index];
                    return _buildReminderTile(context, r, isDark);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTrialCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      children: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('trialRemindersDisabled'),
                  style: AppTextStyles.smallBold(isDark: isDark),
                ),
                const SizedBox(height: 2),
                Text(
                  ref.t('trialRemindersDesc'),
                  style: AppTextStyles.micro(isDark: isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      children: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 44,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              ref.t('noRemindersConfigured'),
              style: AppTextStyles.small(isDark: isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _showAddEditReminderDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(ref.t('addReminder')),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTile(BuildContext context, Reminder r, bool isDark) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: Row(
        children: [
          // Taken status Checkbox icon
          GestureDetector(
            onTap: () {
              ref.read(remindersProvider.notifier).markTaken(r.id);
              showPillSuccess(context, 'Médicament marqué comme pris !');
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (r.taken ?? false)
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (r.taken ?? false) 
                      ? AppColors.primary 
                      : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  width: 2,
                ),
              ),
              child: (r.taken ?? false)
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 14),

          // Time & Medication description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.time,
                      style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ref.t(r.frequency).toUpperCase(),
                        style: AppTextStyles.micro(isDark: isDark).copyWith(fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.medicationName,
                  style: AppTextStyles.smallBold(isDark: isDark).copyWith(
                    decoration: (r.taken ?? false) ? TextDecoration.lineThrough : null,
                    color: (r.taken ?? false) ? AppColors.textMuted : null,
                  ),
                ),
                Text(
                  r.dosage,
                  style: AppTextStyles.micro(isDark: isDark),
                ),
              ],
            ),
          ),

          // Active switch, edit & delete buttons
          Switch(
            value: r.active,
            activeColor: AppColors.primary,
            onChanged: (val) {
              ref.read(remindersProvider.notifier).toggleReminderActive(r.id, val);
            },
          ),
          
          IconButton(
            icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white60 : Colors.black45, size: 20),
            onPressed: () => _showAddEditReminderDialog(context, reminder: r),
          ),
          
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
            onPressed: () => _showDeleteConfirmation(context, r.id),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(2, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10.0),
          child: AppCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: Row(
              children: [
                Skeleton(width: 28, height: 28, borderRadius: 14),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 80, height: 16),
                      SizedBox(height: 6),
                      Skeleton(width: 120, height: 14),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Skeleton(width: 40, height: 20, borderRadius: 10),
              ],
            ),
          ),
        );
      }),
    );
  }
}
