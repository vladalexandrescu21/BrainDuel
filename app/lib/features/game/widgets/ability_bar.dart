import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/features/game/models/ability_model.dart';

class AbilityBar extends StatelessWidget {
  final List<AbilityModel> abilities;
  final List<String> usedAbilities;
  final void Function(AbilityType type) onAbilityTap;
  final String? activeEffect;

  const AbilityBar({
    super.key,
    required this.abilities,
    required this.usedAbilities,
    required this.onAbilityTap,
    this.activeEffect,
  });

  @override
  Widget build(BuildContext context) {
    if (abilities.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: abilities.map((ability) {
        final isUsed = usedAbilities.contains(ability.toTypeString());
        return _AbilityButton(
          ability: ability,
          isUsed: isUsed,
          onTap: isUsed ? null : () => _confirmAndUse(context, ability),
          isFlashing: activeEffect == ability.toTypeString(),
        );
      }).toList(),
    );
  }

  void _confirmAndUse(BuildContext context, AbilityModel ability) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ability.name,
          style: GoogleFonts.exo2(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          ability.description,
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Anulează',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAbilityTap(ability.type);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ability.color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Folosește',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final AbilityModel ability;
  final bool isUsed;
  final VoidCallback? onTap;
  final bool isFlashing;

  const _AbilityButton({
    required this.ability,
    required this.isUsed,
    this.onTap,
    this.isFlashing = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isUsed ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isUsed
                      ? [Colors.grey.shade700, Colors.grey.shade600]
                      : [ability.color, ability.color.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: isUsed
                    ? null
                    : [
                        BoxShadow(
                          color: ability.color.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  ability.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ability.name,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isUsed ? AppColors.textSecondary : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    if (isFlashing) {
      return button
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: 600.ms,
            color: ability.color,
          );
    }

    return button;
  }
}
