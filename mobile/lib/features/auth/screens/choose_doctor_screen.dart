import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/colors.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../shared/utils/localization.dart';
import '../../chat/providers/doctor_provider.dart';

class ChooseDoctorPage extends ConsumerStatefulWidget {
  const ChooseDoctorPage({super.key});

  @override
  ConsumerState<ChooseDoctorPage> createState() => _ChooseDoctorPageState();
}

class _ChooseDoctorPageState extends ConsumerState<ChooseDoctorPage> {
  String _selectedDoctorId = 'dr_sarah';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedDoctorId = ref.read(doctorProvider).id;
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _loading = true;
    });

    try {
      await ref.read(doctorProvider.notifier).selectDoctor(_selectedDoctorId);
    } catch (e) {
      debugPrint('Error selecting doctor: $e');
    }

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDoctor = getDoctorById(_selectedDoctorId);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          // Background soft gradient ambient orbs
          Positioned(
            top: -128,
            right: -128,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(selectedDoctor.accentColorValue).withValues(alpha: isDark ? 0.06 : 0.08),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.isTablet(context) ? 48.0 : 20.0,
                    vertical: 16.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),


                          // Main Question - Luxury Palace Serif Typography (Grand & Centered)
                          Builder(
                            builder: (context) {
                              final rawTitle = ref.t('chooseDoctorTitle');
                              if (rawTitle.contains('\n')) {
                                final parts = rawTitle.split('\n');
                                return RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 32,
                                      height: 1.14,
                                      letterSpacing: -0.3,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${parts[0]}\n',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontStyle: FontStyle.italic,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                      TextSpan(
                                        text: parts.sublist(1).join('\n'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFFF8FAFC)
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Text(
                                rawTitle,
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFF0F172A),
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Subtitle - Warm & Attentive
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              ref.t('chooseDoctorSubtitle'),
                              style: GoogleFonts.inter(
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                                fontSize: 13.5,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // 2x2 Grid of 4 Doctors
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.84,
                            ),
                            itemCount: kAvailableDoctors.length,
                            itemBuilder: (context, index) {
                              final doctor = kAvailableDoctors[index];
                              final isSelected = doctor.id == _selectedDoctorId;
                              final accentColor = Color(doctor.accentColorValue);

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedDoctorId = doctor.id;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.cardDark : AppColors.card,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.20),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        )
                                      else
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Soft gradient circle behind doctor
                                      Positioned(
                                        top: 14,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Container(
                                            width: 92,
                                            height: 92,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  accentColor.withValues(alpha: isSelected ? 0.28 : 0.14),
                                                  accentColor.withValues(alpha: 0.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Content
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Doctor Cutout Portrait (Large & Prominent)
                                            Expanded(
                                              child: Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Image.asset(
                                                    doctor.imagePath,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) => Icon(
                                                      Icons.person,
                                                      size: 48,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Doctor Name (Clean & prominent, without subtitle badge)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  doctor.name,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Selected Checkmark Pill (Top Right)
                                      if (isSelected)
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.45),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          // Confirm Button (Flexible & Responsive on all screen sizes)
                          GestureDetector(
                            onTap: _loading ? null : _handleConfirm,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A))
                                        .withValues(alpha: 0.22),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${ref.t('chooseDoctorConfirm')} (${selectedDoctor.shortName})',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: -0.2,
                                              ),
                                              maxLines: 1,
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
