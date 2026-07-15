import 'package:flutter/material.dart';

/// Official Google "G" logo from asset — no SVG package needed.
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Fallback si l'asset n'est pas trouvé (ne devrait pas arriver)
      errorBuilder: (_, __, ___) => _FallbackGoogleLogo(size: size),
    );
  }
}

/// Fallback text-based G logo (used only if asset fails to load)
class _FallbackGoogleLogo extends StatelessWidget {
  final double size;
  const _FallbackGoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size * 0.65,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
