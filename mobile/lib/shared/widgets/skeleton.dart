import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Shimmer colors matching the React app's tinted skeletons
    final baseColor = isDark 
        ? Colors.blue.withOpacity(0.05) 
        : const Color(0xFF4A90E2).withOpacity(0.05);
    final highlightColor = isDark 
        ? Colors.blue.withOpacity(0.12) 
        : const Color(0xFF4A90E2).withOpacity(0.12);

    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
