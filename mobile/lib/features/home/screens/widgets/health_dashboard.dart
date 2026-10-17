import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/colors.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../data/models/health_stats.dart';
import '../../providers/health_stats_provider.dart';
import '../../../reminders/providers/reminders_provider.dart';
import 'medication_reminders.dart';

class HealthDashboardWidget extends ConsumerWidget {
  const HealthDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(healthStatsProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title + Sort Icon (Refined typography)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.t('healthDashboard'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: isDark ? AppColors.textMutedDark : const Color(0xFF94A3B8),
              ),
            ],
          ),
          const SizedBox(height: 12),

          statsAsync.when(
            loading: () => _buildSkeleton(isDark),
            error: (_, __) => _buildSkeleton(isDark),
            data: (stats) {
              // Extract next reminder time reactively if available from reminders
              final activeReminders = remindersAsync.value?.where((r) => r.active).toList() ?? [];
              String displayNextReminderTime = '--:--';
              if (stats.nextReminderTime != null && stats.nextReminderTime!.isNotEmpty) {
                displayNextReminderTime = stats.nextReminderTime!;
              } else if (activeReminders.isNotEmpty) {
                activeReminders.sort((a, b) => a.nextDose.compareTo(b.nextDose));
                displayNextReminderTime = activeReminders.first.time;
              }

              return _buildDashboardLayout(
                context,
                ref,
                stats,
                displayNextReminderTime,
                isDark,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLayout(
    BuildContext context,
    WidgetRef ref,
    HealthStats stats,
    String nextReminderTime,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth < 360;
    final double cardHeight = isCompact ? 160.0 : 168.0;

    return SizedBox(
      height: cardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT COLUMN: 1 Tall Card (Scans cette semaine + Weekly Bars)
          Expanded(
            flex: 1,
            child: _buildScansTallCard(ref, stats, isDark, isCompact),
          ),
          SizedBox(width: isCompact ? 8 : 12),

          // RIGHT COLUMN: 2 Stacked Cards (Traitements Actifs + Prochain rappel)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Top: Traitements Actifs (Compact card)
                Expanded(
                  child: _buildActiveTreatmentsCompactCard(context, ref, stats, isDark, isCompact),
                ),
                SizedBox(height: isCompact ? 8 : 12),

                // Bottom: Next reminder with orange pending dot
                Expanded(
                  child: _buildNextReminderCard(ref, nextReminderTime, isDark, isCompact),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRemindersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MedicationRemindersWidget(),
    );
  }

  /// Left Tall Card: Scans this week + Minimalist 7-Day Bar Chart
  /// Left Tall Card: Scans this week + Weekly Scan Goal Progress (Option 1)
  Widget _buildScansTallCard(
    WidgetRef ref,
    HealthStats stats,
    bool isDark,
    bool isCompact,
  ) {
    final int scanCount = stats.scansThisWeek;
    const int targetScans = 10;
    final double progress = (scanCount / targetScans).clamp(0.0, 1.0);
    final int percent = (progress * 100).toInt();
    final bool isCompleted = scanCount >= targetScans;

    return Container(
      padding: EdgeInsets.only(
        top: isCompact ? 12 : 14,
        left: isCompact ? 10 : 14,
        right: isCompact ? 10 : 14,
        bottom: isCompact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.85) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scanCount.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: isCompact ? 26 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ref.t('scansThisWeek'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
            ),
          ),
          const Spacer(),

          // Ultra-épuré Minimalist Weekly Goal (10 scans target)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Single sleek caption row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ref.t('weeklyGoal')} : $targetScans',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isCompact ? 10.5 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    isCompleted
                        ? ref.t('weeklyGoalBravo')
                        : '$percent%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isCompact ? 10.5 : 11.5,
                      fontWeight: FontWeight.w700,
                      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              // Ultra-clean thin progress line (3.5px)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 3.5,
                  width: double.infinity,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Right Top Card: Active Treatments + Pill Icon (opens reminders sheet)
  Widget _buildActiveTreatmentsCompactCard(
    BuildContext context,
    WidgetRef ref,
    HealthStats stats,
    bool isDark,
    bool isCompact,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _openRemindersSheet(context);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.85) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stats.pendingReminders.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isCompact ? 19 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ref.t('activeTreatments'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isCompact ? 10.5 : 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.20 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: MedicationCartonIcon(
                    color: Color(0xFF2563EB),
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Right Bottom Card: Next Reminder + Orange Status Dot with subtle glow
  Widget _buildNextReminderCard(WidgetRef ref, String reminderTime, bool isDark, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0).withOpacity(0.7),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                reminderTime,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isCompact ? 17 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ref.t('nextReminder'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isCompact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Orange Pending Dot with soft halo ring
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF97316).withOpacity(0.18),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF97316),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return const SizedBox(
      height: 168,
      child: Row(
        children: [
          Expanded(child: Skeleton(width: double.infinity, height: 168, borderRadius: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Expanded(child: Skeleton(width: double.infinity, height: 78, borderRadius: 18)),
                SizedBox(height: 12),
                Expanded(child: Skeleton(width: double.infinity, height: 78, borderRadius: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom vector icon representing a realistic medication carton/box
class MedicationCartonIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MedicationCartonIcon({
    super.key,
    this.size = 18,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedicationCartonPainter(color: color),
      ),
    );
  }
}

class _MedicationCartonPainter extends CustomPainter {
  final Color color;

  _MedicationCartonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 3D Isometric Medicine Carton
    // Key vertices:
    // Front face: p0(top-left), p1(top-right), p2(bottom-right), p3(bottom-left)
    // Top face: p0, p4(back-left), p5(back-right), p1
    // Side face: p1, p5, p6(back-bottom-right), p2
    final p0 = Offset(w * 0.09, h * 0.34);
    final p1 = Offset(w * 0.68, h * 0.34);
    final p2 = Offset(w * 0.68, h * 0.88);
    final p3 = Offset(w * 0.09, h * 0.88);

    final p4 = Offset(w * 0.31, h * 0.16);
    final p5 = Offset(w * 0.90, h * 0.16);
    final p6 = Offset(w * 0.90, h * 0.70);

    // 1. Top face (lid of the carton)
    final topPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p1.dx, p1.dy)
      ..close();
    final topFill = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawPath(topPath, topFill);

    // 2. Right side face (shadow depth)
    final sidePath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p6.dx, p6.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final sideFill = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(sidePath, sideFill);

    // 3. Front face (main carton body)
    final frontPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    final frontFill = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawPath(frontPath, frontFill);

    // 4. Pharmaceutical Color Band (wraps across front and right side)
    final bandH = h * 0.14;
    final frontBand = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p1.dx, p0.dy + bandH)
      ..lineTo(p0.dx, p0.dy + bandH)
      ..close();
    final bandPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(frontBand, bandPaint);

    // Side wrapping band
    final sideBand = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p5.dx, p5.dy + bandH)
      ..lineTo(p1.dx, p1.dy + bandH)
      ..close();
    final sideBandPaint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    canvas.drawPath(sideBand, sideBandPaint);

    // 5. Carton Structural Edges (Outlines)
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(frontPath, strokePaint);
    canvas.drawPath(topPath, strokePaint);
    canvas.drawPath(sidePath, strokePaint);

    // Top flap center crease line (authentic tuck tab)
    final flapCrease = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawLine(
      Offset((p0.dx + p4.dx) / 2, (p0.dy + p4.dy) / 2),
      Offset((p1.dx + p5.dx) / 2, (p1.dy + p5.dy) / 2),
      flapCrease,
    );

    // 6. Medical Cross Emblem (front face)
    final crossPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cx = (p0.dx + p1.dx) / 2;
    final cy = h * 0.65;
    final r = w * 0.09;

    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), crossPaint);

    // 7. Prescription / Dosage micro-line (medication packaging detail)
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.22, h * 0.80),
      Offset(w * 0.55, h * 0.80),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MedicationCartonPainter oldDelegate) =>
      color != oldDelegate.color;
}
