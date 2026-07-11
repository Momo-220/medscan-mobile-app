import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/colors.dart';

class CustomNavigationBar extends StatelessWidget {
  final String currentPath;

  const CustomNavigationBar({
    super.key,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    // Determine active tab based on path
    final bool isHome = currentPath == '/home';
    final bool isChat = currentPath == '/chat';
    final bool isPharmacy = currentPath == '/pharmacy' || currentPath == '/history';
    final bool isSettings = currentPath == '/settings';

    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final double bottomMargin = safeAreaBottom > 0 ? safeAreaBottom : 20.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: bottomMargin,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The Navigation Bar Container
          Container(
            height: 85,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A3B5D).withOpacity(0.06),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  isActive: isHome,
                  onTap: () => context.go('/home'),
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  isActive: isChat,
                  onTap: () => context.go('/chat'),
                ),
                // Spacer for the center Scan button
                const SizedBox(width: 68),
                _buildNavItem(
                  context: context,
                  icon: Icons.local_pharmacy_outlined,
                  activeIcon: Icons.local_pharmacy,
                  isActive: isPharmacy,
                  onTap: () => context.go('/pharmacy'),
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  isActive: isSettings,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ),

          // Central FAB Portal Button
          Positioned(
            left: 0,
            right: 0,
            top: -24,
            child: Center(
              child: GestureDetector(
                onTap: () => context.push('/scan'),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: AppColors.scanButtonGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.textMutedDark : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 85,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 26,
            ),
            if (isActive)
              Positioned(
                bottom: 18,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
