import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brainduel/core/theme/app_theme.dart';

enum AnswerButtonState {
  normal,
  selected,
  correct,
  wrong,
  opponentChose,
  disabled,
  eliminated,
}

class AnswerButton extends StatelessWidget {
  final int index;
  final String text;
  final AnswerButtonState buttonState;
  final VoidCallback? onTap;

  const AnswerButton({
    super.key,
    required this.index,
    required this.text,
    required this.buttonState,
    this.onTap,
  });

  static const List<String> _letters = ['A', 'B', 'C', 'D'];

  Color _backgroundColor() {
    switch (buttonState) {
      case AnswerButtonState.selected:
        return AppColors.secondary.withOpacity(0.35);
      case AnswerButtonState.correct:
        return AppColors.correct.withOpacity(0.35);
      case AnswerButtonState.wrong:
        return AppColors.wrong.withOpacity(0.35);
      case AnswerButtonState.opponentChose:
        return AppColors.primary.withOpacity(0.2);
      case AnswerButtonState.eliminated:
        return Colors.white.withOpacity(0.03);
      case AnswerButtonState.normal:
      case AnswerButtonState.disabled:
        return AppColors.cardBg;
    }
  }

  Color _borderColor() {
    switch (buttonState) {
      case AnswerButtonState.selected:
        return AppColors.secondary;
      case AnswerButtonState.correct:
        return AppColors.correct;
      case AnswerButtonState.wrong:
        return AppColors.wrong;
      case AnswerButtonState.opponentChose:
        return AppColors.primary;
      case AnswerButtonState.eliminated:
        return Colors.white.withOpacity(0.05);
      case AnswerButtonState.normal:
        return Colors.white.withOpacity(0.12);
      case AnswerButtonState.disabled:
        return Colors.white.withOpacity(0.08);
    }
  }

  Color _letterBadgeColor() {
    switch (buttonState) {
      case AnswerButtonState.correct:
        return AppColors.correct;
      case AnswerButtonState.wrong:
        return AppColors.wrong;
      case AnswerButtonState.selected:
        return AppColors.secondary;
      case AnswerButtonState.opponentChose:
        return AppColors.primary;
      default:
        return AppColors.primary.withOpacity(0.7);
    }
  }

  Color _textColor() {
    if (buttonState == AnswerButtonState.eliminated) {
      return AppColors.textSecondary.withOpacity(0.3);
    }
    if (buttonState == AnswerButtonState.disabled) {
      return AppColors.textSecondary;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = buttonState == AnswerButtonState.normal;

    return GestureDetector(
      onTap: isInteractive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _backgroundColor(),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor(), width: 1.5),
          boxShadow: buttonState == AnswerButtonState.correct
              ? [
                  BoxShadow(
                    color: AppColors.correct.withOpacity(0.3),
                    blurRadius: 8,
                  )
                ]
              : buttonState == AnswerButtonState.wrong
                  ? [
                      BoxShadow(
                        color: AppColors.wrong.withOpacity(0.3),
                        blurRadius: 8,
                      )
                    ]
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _letterBadgeColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _letters[index],
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textColor(),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (buttonState == AnswerButtonState.correct)
              const Icon(Icons.check_circle, color: AppColors.correct, size: 18),
            if (buttonState == AnswerButtonState.wrong)
              const Icon(Icons.cancel, color: AppColors.wrong, size: 18),
          ],
        ),
      ),
    );
  }
}
