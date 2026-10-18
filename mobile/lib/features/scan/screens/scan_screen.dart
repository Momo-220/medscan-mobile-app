import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/navigation_bar.dart';
import '../../../shared/utils/pill_notification.dart';
import '../providers/scan_provider.dart';

import 'custom_camera_screen.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      String? imagePath;
      if (source == ImageSource.camera) {
        // Open our custom camera page with the refined scan overlay frame
        imagePath = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const CustomCameraPage()),
        );
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1920,
        );
        imagePath = image?.path;
      }

      if (imagePath != null) {
        setState(() {
          _selectedImage = File(imagePath!);
        });
        _startScanning();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _startScanning() async {
    if (_selectedImage == null) return;

    _scanLineController.repeat(reverse: true);
    final langCode = ref.read(languageProvider);

    try {
      final result = await ref.read(scanProvider.notifier).uploadAndScan(
            _selectedImage!,
            langCode,
          );

      if (result != null && mounted) {
        final resultMap = result.toJson();
        if (_selectedImage != null && _selectedImage!.existsSync()) {
          resultMap['local_image_path'] = _selectedImage!.path;
        }
        context.pushReplacement('/scan-result', extra: resultMap);
      }
    } catch (e) {
      _scanLineController.stop();
      
      final scanState = ref.read(scanProvider);
      if (scanState.error == 'INSUFFICIENT_CREDITS' && mounted) {
        _showCreditsDialog(context);
      } else if (scanState.error != null && mounted) {
        showPillError(context, scanState.error!);
      }
    }
  }

  void _cancelScan() {
    ref.read(scanProvider.notifier).reset();
    _scanLineController.stop();
    setState(() {
      _selectedImage = null;
    });
  }

  void _showCreditsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red[50]!.withOpacity(isDark ? 0.15 : 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('💎', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 16),
                Text(
                  ref.t('insufficientCredits'),
                  style: AppTextStyles.h3(isDark: isDark),
                ),
                const SizedBox(height: 12),
                Text(
                  isAnonymous
                      ? ref.t('trialOrSignInTagline')
                      : ref.t('gemsDepletedMessage'),
                  style: AppTextStyles.small(isDark: isDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (isAnonymous) ...[
                  Button(
                    width: double.infinity,
                    onTap: () {
                      Navigator.pop(context); // Close dialog
                      _cancelScan();          // Cancel scan state
                      context.go('/auth');    // Navigate to auth
                    },
                    child: Text(ref.t('signInOrRegister')),
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _cancelScan();
                    context.pop(); // Close scan screen
                  },
                  child: Text(ref.t('close')),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scanState = ref.watch(scanProvider);

    // If an image is selected and loading, show full screen Scanning overlay
    if (_selectedImage != null && scanState.loading) {
      return _buildScanningOverlay(context, scanState, isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          ref.t('scanMedication'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Button: Take Photo (Circular Shutter Button)
                  Expanded(
                    child: CircularScanButton(
                      onTap: () => _pickImage(ImageSource.camera),
                      icon: Icons.camera_alt_rounded,
                      title: ref.t('takePhoto'),
                      subtitle: ref.t('cameraThenAnalyze'),
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right Button: Upload Photo (Circular Gallery Button)
                  Expanded(
                    child: CircularScanButton(
                      onTap: () => _pickImage(ImageSource.gallery),
                      icon: Icons.photo_library_rounded,
                      title: ref.t('uploadPhoto'),
                      subtitle: 'JPEG, PNG',
                      isPrimary: false,
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

  Widget _buildScanningOverlay(BuildContext context, ScanState scanState, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF3F8FF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main Body
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ResponsiveContainer(
                maxWidth: 580,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                  
                  // Back button or Cancel Analysis text button at top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _cancelScan,
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ref.t('back'),
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelScan,
                        child: Text(
                          ref.t('cancel'),
                          style: AppTextStyles.smallBold(isDark: isDark).copyWith(
                            color: Colors.red[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Image scanner container with crop corners and vertical scan line animation
                  Center(
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : const Color(0xFFE2EBF6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFD0E1F4),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            
                            // Blue crop corners
                            Positioned.fill(
                              child: Stack(
                                children: [
                                  // Top Left
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                          left: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Top Right
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                          right: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom Left
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                          left: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom Right
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                          right: BorderSide(color: Color(0xFF3B82F6), width: 4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Scanning line animation
                            AnimatedBuilder(
                              animation: _scanLineAnimation,
                              builder: (context, child) {
                                final double cardHeight = 288; // 320 - 32 padding
                                final double topOffset = _scanLineAnimation.value * cardHeight;
                                return Positioned(
                                  top: topOffset,
                                  left: 10,
                                  right: 10,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00F5D4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00F5D4).withOpacity(0.8),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Progress state Row & progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              scanState.statusText ?? ref.t('analyzing'),
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              tween: Tween<double>(
                                begin: 0,
                                end: scanState.progressPercent.toDouble(),
                              ),
                              builder: (context, value, child) {
                                return Text(
                                  '${value.toInt()}%',
                                  style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                    fontSize: 16,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            begin: 0,
                            end: (scanState.progressPercent / 100.0).clamp(0.0, 1.0),
                          ),
                          builder: (context, value, child) {
                            return Container(
                              height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value.clamp(0.0, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF60A5FA),
                                        Color(0xFF00F5D4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withOpacity(0.35),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120), // Spacing buffer
                ],
              ),
            ),
          ),
        ),

          // Docked Bottom Navigation Bar with Mascot Support (Cat sitting on the navbar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomNavigationBar(
              currentPath: '/scan',
              mascot: AnimatedOpacity(
                opacity: scanState.loading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: SizedBox(
                  width: 145,
                  height: 145,
                  child: Lottie.asset(
                    'assets/animations/cat_scan.json',
                    repeat: true,
                    animate: scanState.loading,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircularScanButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;

  const CircularScanButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isPrimary = false,
  });

  @override
  State<CircularScanButton> createState() => _CircularScanButtonState();
}

class _CircularScanButtonState extends State<CircularScanButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Button Trigger with Scale Animation
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isPrimary
                      ? const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.40 : 0.28)
                      : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isPrimary
                      ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.isPrimary
                      ? null
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  border: Border.all(
                    color: widget.isPrimary
                        ? Colors.white.withValues(alpha: 0.28)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                    width: 1.2,
                  ),
                  boxShadow: [
                    if (widget.isPrimary) ...[
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.45 : 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: isDark ? 0.25 : 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ] else ...[
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.35 : 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.15 : 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.isPrimary
                        ? Colors.white
                        : const Color(0xFF2563EB),
                    size: 36,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Subtitle
          Text(
            widget.subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

typedef ScanActionButton = CircularScanButton;


