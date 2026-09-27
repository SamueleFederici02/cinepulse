import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DynamicAmbientBackground extends StatelessWidget {
  final Color primaryGlow;
  final Color secondaryGlow;
  final Widget child;

  const DynamicAmbientBackground({
    super.key,
    this.primaryGlow = AppColors.primaryOrange,
    this.secondaryGlow = AppColors.electricCyan,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sfondo base OLED
        Container(color: AppColors.background),

        // Glow 1 Superiore
        Positioned(
          top: -120,
          left: -80,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryGlow.withOpacity(0.18),
            ),
          ),
        ),

        // Glow 2 Inferiore
        Positioned(
          bottom: 100,
          right: -100,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: secondaryGlow.withOpacity(0.14),
            ),
          ),
        ),

        // Backdrop Filter per sfocatura organica ultra-morbida
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),

        // Contenuto sopra lo sfondo
        child,
      ],
    );
  }
}
