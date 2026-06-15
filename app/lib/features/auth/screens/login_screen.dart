// ignore_for_file: prefer_const_constructors
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/shared/widgets/brain_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showEmailForm = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildLogo(),
                const SizedBox(height: 48),
                if (_showEmailForm)
                  _buildEmailForm(authState)
                else
                  _buildButtons(authState),
                if (authState.error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorBanner(authState.error!),
                ],
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 28,
                spreadRadius: 6,
              ),
            ],
          ),
          child: SvgPicture.asset(
            'assets/images/logo_icon.svg',
            width: 110,
            height: 110,
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 20),
        SvgPicture.asset(
          'assets/images/logo.svg',
          width: 260,
          height: 70,
          fit: BoxFit.contain,
        )
            .animate()
            .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 200.ms)
            .fadeIn(duration: 500.ms, delay: 200.ms),
        const SizedBox(height: 10),
        Text(
          S.tagline,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.secondary,
          ),
        )
            .animate()
            .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 350.ms)
            .fadeIn(duration: 500.ms, delay: 350.ms),
      ],
    );
  }

  Widget _buildButtons(AuthState authState) {
    return Column(
      children: [
        if (!kIsWeb) ...[
          _GoogleSignInButton(
            isLoading: authState.isLoading,
            onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
          )
              .animate()
              .slideY(begin: 0.5, end: 0, duration: 500.ms, delay: 450.ms)
              .fadeIn(duration: 500.ms, delay: 450.ms),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 56,
          width: double.infinity,
          child: TextButton(
            onPressed: authState.isLoading
                ? null
                : () => setState(() => _showEmailForm = true),
            child: Text(
              S.continueWithEmail,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        )
            .animate()
            .slideY(begin: 0.5, end: 0, duration: 500.ms, delay: 550.ms)
            .fadeIn(duration: 500.ms, delay: 550.ms),
      ],
    );
  }

  Widget _buildEmailForm(AuthState authState) {
    return Column(
      children: [
        if (_isRegisterMode) ...[
          _buildTextField(
            controller: _nameController,
            label: S.displayName,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),
        ],
        _buildTextField(
          controller: _emailController,
          label: S.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _passwordController,
          label: S.password,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),
        BrainButton(
          label: _isRegisterMode ? S.register : S.login,
          isLoading: authState.isLoading,
          onPressed: () {
            if (_isRegisterMode) {
              ref.read(authProvider.notifier).registerWithEmail(
                    _emailController.text.trim(),
                    _passwordController.text,
                    _nameController.text.trim(),
                  );
            } else {
              ref.read(authProvider.notifier).signInWithEmail(
                    _emailController.text.trim(),
                    _passwordController.text,
                  );
            }
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: authState.isLoading
              ? null
              : () => setState(() => _isRegisterMode = !_isRegisterMode),
          child: Text(
            _isRegisterMode ? S.alreadyHaveAccount : S.noAccount,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.secondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _showEmailForm = false;
            _isRegisterMode = false;
          }),
          child: Text(
            S.cancel,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBg,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.wrong.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.wrong.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.wrong, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.wrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleLogo(),
            const SizedBox(width: 8),
            Text(
              S.continueWithGoogle,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
