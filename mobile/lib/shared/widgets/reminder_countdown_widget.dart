import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../utils/localization.dart';

class ReminderCountdownWidget extends ConsumerStatefulWidget {
  final DateTime nextDose;
  final bool active;
  final bool taken;

  const ReminderCountdownWidget({
    super.key,
    required this.nextDose,
    required this.active,
    required this.taken,
  });

  @override
  ConsumerState<ReminderCountdownWidget> createState() => _ReminderCountdownWidgetState();
}

class _ReminderCountdownWidgetState extends ConsumerState<ReminderCountdownWidget> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.85,
      upperBound: 1.05,
    )..repeat(reverse: true);
    
    _updateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ReminderCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.active || widget.taken) return;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateRemaining();
      }
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    setState(() {
      _remaining = widget.nextDose.difference(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    
    if (widget.taken) {
      return const SizedBox.shrink();
    }

    if (_remaining.isNegative) {
      return ScaleTransition(
        scale: _pulseController,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red[50]!.withOpacity(isDark ? 0.15 : 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[300]!.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_on, color: Colors.red[500], size: 14),
              const SizedBox(width: 4),
              Text(
                ref.t('dueNow'),
                style: AppTextStyles.micro(isDark: isDark).copyWith(
                  color: isDark ? Colors.red[300] : Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    final displayString = ref.t('inHoursMinutesSeconds')
        .replaceAll('{h}', hours)
        .replaceAll('{m}', minutes)
        .replaceAll('{s}', seconds);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: AppColors.primary,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            displayString,
            style: AppTextStyles.micro(isDark: isDark).copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
