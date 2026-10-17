import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../reminders/providers/reminders_provider.dart';
import '../../../../data/models/reminder.dart';
import '../../../../shared/utils/pill_notification.dart';
import '../../../../shared/widgets/reminder_countdown_widget.dart';

/// Opens a responsive, modern iOS-style modal bottom sheet to add or edit a reminder.
void showAddEditReminderDialog(
  BuildContext context,
  WidgetRef ref, {
  Reminder? reminder,
  String? initialMedicationName,
  String? initialDosage,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isEdit = reminder != null;

  final nameController = TextEditingController(text: reminder?.medicationName ?? initialMedicationName ?? '');
  final dosageController = TextEditingController(text: reminder?.dosage ?? initialDosage ?? '');

  // Default time parsing
  String selectedTime = reminder?.time ?? '08:00';
  final initialParts = selectedTime.split(':');
  TimeOfDay timeOfDay = TimeOfDay(
    hour: int.tryParse(initialParts[0]) ?? 8,
    minute: int.tryParse(initialParts[1]) ?? 0,
  );

  String selectedFrequency = reminder?.frequency ?? 'daily';
  if (selectedFrequency == 'custom') {
    selectedFrequency = 'daily';
  }
  List<int> selectedDays = List<int>.from(reminder?.days ?? []);
  bool customDaysEnabled = reminder?.days != null && reminder!.days!.isNotEmpty;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final mediaQuery = MediaQuery.of(context);
          final keyboardHeight = mediaQuery.viewInsets.bottom;

          return Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, keyboardHeight > 0 ? keyboardHeight + 12 : 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 580,
                  maxHeight: mediaQuery.size.height * 0.84,
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: keyboardHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Header bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isEdit ? ref.t('editReminder') : ref.t('addReminder'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(modalContext),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF334155).withOpacity(0.5)
                                        : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Medication Name Input
                                Text(
                                  ref.t('medicationName'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameController,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: ref.t('medicationNameHint'),
                                    hintStyle: TextStyle(
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontSize: 13.5,
                                    ),
                                    prefixIcon: const Icon(
                                      CupertinoIcons.capsule,
                                      size: 18,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A).withOpacity(0.5)
                                        : const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                        width: 0.8,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                        width: 0.8,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Dosage Input
                                Text(
                                  ref.t('dosage'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: dosageController,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: ref.t('dosageHint'),
                                    hintStyle: TextStyle(
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontSize: 13.5,
                                    ),
                                    prefixIcon: const Icon(
                                      CupertinoIcons.slider_horizontal_3,
                                      size: 18,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A).withOpacity(0.5)
                                        : const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                        width: 0.8,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                        width: 0.8,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Time Selector Row (Minimalist iOS Style)
                                Text(
                                  ref.t('time'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () async {
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
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0F172A).withOpacity(0.5)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.clock,
                                              size: 18,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              ref.t('time'),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFEEF2F6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            selectedTime,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Frequency Selector (Segmented iOS Control Style)
                                Text(
                                  ref.t('frequency'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _SlidingFrequencySelector(
                                  selectedValue: selectedFrequency,
                                  isDark: isDark,
                                  ref: ref,
                                  onValueChanged: (val) {
                                    setDialogState(() => selectedFrequency = val);
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Custom Days Switch Row
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A).withOpacity(0.5)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ref.t('customDaysActive'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      CupertinoSwitch(
                                        value: customDaysEnabled,
                                        activeColor: const Color(0xFF3B82F6),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            customDaysEnabled = val;
                                            if (val && selectedDays.isEmpty) {
                                              selectedDays = [0, 1, 2, 3, 4, 5, 6];
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                if (customDaysEnabled) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(7, (index) {
                                      final dayNames = [
                                        ref.t('mondayShort'),
                                        ref.t('tuesdayShort'),
                                        ref.t('wednesdayShort'),
                                        ref.t('thursdayShort'),
                                        ref.t('fridayShort'),
                                        ref.t('saturdayShort'),
                                        ref.t('sundayShort'),
                                      ];
                                      final isSelected = selectedDays.contains(index);
                                      return GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              selectedDays.remove(index);
                                            } else {
                                              selectedDays.add(index);
                                            }
                                          });
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 140),
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A))
                                                : (isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF1F5F9)),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              dayNames[index],
                                              style: GoogleFonts.plusJakartaSans(
                                                color: isSelected
                                                    ? Colors.white
                                                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // Save Action Button (Sleek, low-contrast, Apple-style)
                                GestureDetector(
                                  onTap: () async {
                                    final name = nameController.text.trim();
                                    final dosage = dosageController.text.trim();

                                    if (name.isEmpty) return;

                                    try {
                                      if (isEdit) {
                                        await ref.read(remindersProvider.notifier).updateReminder(
                                              id: reminder.id,
                                              medicationName: name,
                                              dosage: dosage,
                                              time: selectedTime,
                                              frequency: selectedFrequency,
                                              active: reminder.active,
                                              days: customDaysEnabled ? selectedDays : null,
                                            );
                                      } else {
                                        await ref.read(remindersProvider.notifier).addReminder(
                                              medicationName: name,
                                              dosage: dosage,
                                              time: selectedTime,
                                              frequency: selectedFrequency,
                                              days: customDaysEnabled ? selectedDays : null,
                                            );
                                      }
                                      if (modalContext.mounted) Navigator.pop(modalContext);
                                    } catch (_) {}
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isEdit ? ref.t('edit') : ref.t('create'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _SlidingFrequencySelector extends StatefulWidget {
  final String selectedValue;
  final ValueChanged<String> onValueChanged;
  final bool isDark;
  final WidgetRef ref;

  const _SlidingFrequencySelector({
    required this.selectedValue,
    required this.onValueChanged,
    required this.isDark,
    required this.ref,
  });

  @override
  State<_SlidingFrequencySelector> createState() => _SlidingFrequencySelectorState();
}

class _SlidingFrequencySelectorState extends State<_SlidingFrequencySelector> {
  bool _isDragging = false;
  double? _dragPositionX;
  int _hoveredIndex = 0;

  List<Map<String, String>> _getOptions() {
    return [
      {'value': 'daily', 'label': widget.ref.t('daily')},
      {'value': 'twice', 'label': widget.ref.t('twice')},
      {'value': 'three-times', 'label': widget.ref.t('threeTimes')},
    ];
  }

  int _getIndexForValue(String val) {
    final opts = _getOptions();
    final idx = opts.indexWhere((o) => o['value'] == val);
    return idx < 0 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _hoveredIndex = _getIndexForValue(widget.selectedValue);
  }

  @override
  void didUpdateWidget(covariant _SlidingFrequencySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _hoveredIndex = _getIndexForValue(widget.selectedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _getOptions();
    final selectedIndex = _getIndexForValue(widget.selectedValue);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.55)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double segmentWidth = totalWidth / 3;

          double pillLeft;
          if (_isDragging && _dragPositionX != null) {
            final double rawLeft = _dragPositionX! - (segmentWidth / 2);
            pillLeft = rawLeft.clamp(0.0, totalWidth - segmentWidth);
          } else {
            pillLeft = selectedIndex * segmentWidth;
          }

          final activeIndex = _isDragging ? _hoveredIndex : selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final idx = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              _hoveredIndex = idx;
            },
            onTapUp: (details) {
              final idx = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              HapticFeedback.lightImpact();
              widget.onValueChanged(options[idx]['value']!);
            },
            onHorizontalDragStart: (details) {
              final idx = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              setState(() {
                _isDragging = true;
                _dragPositionX = details.localPosition.dx;
                _hoveredIndex = idx;
              });
              HapticFeedback.selectionClick();
            },
            onHorizontalDragUpdate: (details) {
              final newHovered = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              if (newHovered != _hoveredIndex) {
                _hoveredIndex = newHovered;
                HapticFeedback.selectionClick();
              }
              setState(() {
                _dragPositionX = details.localPosition.dx;
              });
            },
            onHorizontalDragEnd: (_) {
              final chosen = _hoveredIndex;
              setState(() {
                _isDragging = false;
                _dragPositionX = null;
              });
              HapticFeedback.lightImpact();
              widget.onValueChanged(options[chosen]['value']!);
            },
            onHorizontalDragCancel: () {
              setState(() {
                _isDragging = false;
                _dragPositionX = null;
                _hoveredIndex = selectedIndex;
              });
            },
            child: Stack(
              children: [
                // 1. Fluid Sliding & Dragging White / Slate Pill
                AnimatedPositioned(
                  duration: _isDragging ? Duration.zero : const Duration(milliseconds: 280),
                  curve: Curves.fastOutSlowIn,
                  left: pillLeft,
                  top: 0,
                  width: segmentWidth,
                  height: 34,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF334155) : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.08),
                          blurRadius: _isDragging ? 8 : 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Interactive Options Row
                Row(
                  children: List.generate(options.length, (index) {
                    final opt = options[index];
                    final isSelected = activeIndex == index;
                    return Expanded(
                      child: SizedBox(
                        height: 34,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (widget.isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                            child: Text(
                              opt['label']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The complete medication reminders modal sheet component
class MedicationRemindersWidget extends ConsumerStatefulWidget {
  const MedicationRemindersWidget({super.key});

  @override
  ConsumerState<MedicationRemindersWidget> createState() => _MedicationRemindersWidgetState();
}

class _MedicationRemindersWidgetState extends ConsumerState<MedicationRemindersWidget> {
  void _showAddEditReminder(BuildContext context, {Reminder? reminder}) {
    showAddEditReminderDialog(context, ref, reminder: reminder);
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            ref.t('deleteReminder'),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            ref.t('confirmDeleteReminder'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(ref.t('close'), style: TextStyle(color: isDark ? Colors.white60 : Colors.black45)),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(remindersProvider.notifier).deleteReminder(id);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: Text(
                ref.t('delete'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final isAnonymous = user?.isAnonymous ?? false;

    final mediaQuery = MediaQuery.sizeOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: mediaQuery.height * 0.82,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header Bar (Clean, low-contrast)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ref.t('medicationRemindersTitle'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          if (!isAnonymous)
                            GestureDetector(
                              onTap: () => _showAddEditReminder(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '+ ${ref.t('add')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155).withOpacity(0.5)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Scrollable List of Reminders / Empty State
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: isAnonymous
                        ? _buildTrialCard(isDark)
                        : remindersAsync.when(
                            loading: () => _buildSkeletonList(),
                            error: (err, stack) => const SizedBox(),
                            data: (reminders) {
                              if (reminders.isEmpty) {
                                return _buildEmptyCard(isDark);
                              }

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool isWide = constraints.maxWidth >= 540;
                                  if (isWide) {
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: reminders.length,
                                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 380,
                                        mainAxisExtent: 140,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                      itemBuilder: (context, index) {
                                        final r = reminders[index];
                                        return _buildReminderTile(context, r, isDark);
                                      },
                                    );
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
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildTrialCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.lock, color: Color(0xFF3B82F6), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('trialRemindersDisabled'),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ref.t('trialRemindersDesc'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Modern, minimalist, airy empty state with low contrast
  Widget _buildEmptyCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Icon(
              CupertinoIcons.bell,
              size: 24,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ref.t('noRemindersConfigured'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ref.t('configureRemindersDesc'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showAddEditReminder(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  '+ ${ref.t('addReminder')}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(BuildContext context, Reminder r, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time & Medication description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.time,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ref.t(r.frequency).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.medicationName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: r.isUpToDate ? TextDecoration.lineThrough : null,
                    color: r.isUpToDate
                        ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (r.dosage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.dosage,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 6),
                ReminderCountdownWidget(
                  nextDose: r.nextDose,
                  active: r.active,
                  status: r.status,
                  dosesTaken: r.dosesTakenToday,
                  totalDoses: r.totalDosesToday,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Actions Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.65,
                    child: CupertinoSwitch(
                      value: r.active,
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (val) {
                        ref.read(remindersProvider.notifier).toggleReminderActive(r.id, val);
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAddEditReminder(context, reminder: r),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.pencil,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showDeleteConfirmation(context, r.id),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.trash,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444).withOpacity(0.7),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  if (r.status == ReminderStatus.due) {
                    ref.read(remindersProvider.notifier).markTaken(r.id);
                    showPillSuccess(context, ref.t('doseMarkedTaken'));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: r.status == ReminderStatus.completed
                        ? (isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5))
                        : (r.status == ReminderStatus.due
                            ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.4) : const Color(0xFFEFF6FF))
                            : (isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC))),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: r.status == ReminderStatus.completed
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : (r.status == ReminderStatus.due
                              ? const Color(0xFF3B82F6).withOpacity(0.3)
                              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.status == ReminderStatus.completed)
                        const Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF10B981), size: 13),
                      if (r.status == ReminderStatus.pending)
                        Icon(CupertinoIcons.time, color: isDark ? Colors.white54 : const Color(0xFF94A3B8), size: 13),
                      if (r.status != ReminderStatus.due)
                        const SizedBox(width: 4),
                      Text(
                        r.status == ReminderStatus.completed
                            ? ref.t('reminderCompleted')
                            : (r.status == ReminderStatus.pending ? ref.t('reminderPending') : ref.t('takeDose')),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: r.status == ReminderStatus.completed
                              ? const Color(0xFF059669)
                              : (r.status == ReminderStatus.due
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(2, (index) => _buildSkeletonItem()),
    );
  }

  Widget _buildSkeletonItem() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10.0),
      child: Skeleton(width: double.infinity, height: 90, borderRadius: 20),
    );
  }
}
