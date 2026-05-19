import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brainduel/core/theme/app_theme.dart';

class TimerBar extends StatelessWidget {
  final AnimationController controller;
  final int totalSeconds;

  const TimerBar({
    super.key,
    required this.controller,
    required this.totalSeconds,
  });

  Color _timerColor(double progress) {
    // progress goes from 1.0 (full) to 0.0 (empty)
    if (progress > 0.6) return AppColors.timerFull;
    if (progress > 0.3) return AppColors.timerMid;
    return AppColors.timerEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value; // 1.0 → 0.0
        final secondsLeft = (progress * totalSeconds).ceil();
        final color = _timerColor(progress);

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Background track
                  Container(
                    height: 10,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  // Animated fill
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$secondsLeft',
              style: GoogleFonts.exo2(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}
