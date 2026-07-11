import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class Loading extends StatelessWidget {
  final String text;

  const Loading({
    super.key,
    this.text = 'Chargement...',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              backgroundColor: AppColors.primaryLight.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: AppTextStyles.body(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class OrganicWaveLoader extends StatefulWidget {
  final String text;

  const OrganicWaveLoader({
    super.key,
    this.text = 'Analyse en cours...',
  });

  @override
  State<OrganicWaveLoader> createState() => _OrganicWaveLoaderState();
}

class _OrganicWaveLoaderState extends State<OrganicWaveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer breathing border
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = 1.0 + (_controller.value * 0.15);
                  final opacity = 0.3 * (1.0 - _controller.value);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(opacity),
                          width: 4,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Inner static dot
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            widget.text,
            style: AppTextStyles.bodyBold(isDark: isDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Cela peut prendre quelques secondes',
            style: AppTextStyles.small(isDark: isDark),
          ),
        ],
      ),
    );
  }
}
