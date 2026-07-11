import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
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
        // Stop animation and go to results
        _scanLineController.stop();
        context.pushReplacement('/scan-result', extra: result.toJson());
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
                      : 'Vous avez épuisé vos gemmes quotidiennes. Veuillez patienter jusqu\'à minuit pour votre renouvellement.',
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
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          ref.t('scanMedication'),
          style: AppTextStyles.h3(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Banner Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A3B5D).withOpacity(0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '📸',
                                style: TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ref.t('scanMethodTitle'),
                                      style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ref.t('scanMethodSubtitle'),
                                      style: AppTextStyles.small(
                                        color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                                      ).copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Spacer(), // Centering Spacer at the top

                        // 2. Row of Two Side-by-Side Cards (Reduced size)
                        Row(
                          children: [
                            // Left Card: Upload Photo
                            Expanded(
                              child: ScanActionButton(
                                onTap: () => _pickImage(ImageSource.gallery),
                                icon: Icons.photo_library_rounded,
                                title: ref.t('uploadPhoto'),
                                subtitle: 'JPEG / PNG',
                                gradientColors: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                                shadowColor: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Right Card: Take Photo
                            Expanded(
                              child: ScanActionButton(
                                onTap: () => _pickImage(ImageSource.camera),
                                icon: Icons.camera_alt_rounded,
                                title: ref.t('takePhoto'),
                                subtitle: ref.t('cameraThenAnalyze'),
                                gradientColors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                shadowColor: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                        
                        const Spacer(),
                        
                        // Bottom Disclaimer
                        const SizedBox(height: 32),
                        Center(
                          child: Text(
                            ref.t('disclaimerMedical'),
                            style: AppTextStyles.micro(isDark: isDark),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
                          'Cancel',
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(
                              begin: 0,
                              end: scanState.progressPercent / 100.0,
                            ),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                minHeight: 8,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120), // Spacing buffer
                ],
              ),
            ),
          ),

          // Docked Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomNavigationBar(currentPath: '/scan'),
          ),
        ],
      ),
    );
  }
}

class ScanActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color shadowColor;

  const ScanActionButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.shadowColor,
  });

  @override
  State<ScanActionButton> createState() => _ScanActionButtonState();
}

class _ScanActionButtonState extends State<ScanActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.gradientColors[0].withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  left: -10,
                  bottom: -10,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
