import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/auth/auth_service.dart';

/// Reset password request — layout and styling from Stitch
/// (DukaNest Tenant App Plan, screen "Reset Password").
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  String? _error;

  static final Uri _supportUri = Uri.parse('mailto:support@dukanest.com');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
      _error = null;
    });

    final response = await ref
        .read(authServiceProvider)
        .requestPasswordReset(_emailController.text.trim());

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (response.success) {
      final msg = response.data?['message'] as String?;
      setState(() {
        _message = msg ??
            'If an account exists with this email, a password reset link has been sent.';
      });
    } else {
      setState(() {
        _error = response.error?.message ?? 'Could not send reset link.';
      });
    }
  }

  Future<void> _openSupport() async {
    try {
      final launched = await launchUrl(_supportUri);
      if (!mounted || launched) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact support@dukanest.com')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final headlineStyle = GoogleFonts.plusJakartaSans(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppTheme.primaryDark,
      height: 1.15,
    );

    final bodyStyle = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppTheme.onSurfaceVariant,
      height: 1.5,
    );

    final labelStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppTheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    final hintStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: colorScheme.outline,
    );

    final smallHintStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: colorScheme.outline,
    );

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppTheme.primary,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DukaNest',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryDark,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(32, 12, 32, 96),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.lock_reset_rounded,
                            size: 40,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Reset Password', style: headlineStyle),
                        const SizedBox(height: 16),
                        Text(
                          'Enter the email address associated with your account and we\'ll '
                          'send you a link to reset your password.',
                          style: bodyStyle,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'EMAIL ADDRESS',
                          style: labelStyle,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. alex@business.com',
                            hintStyle: hintStyle,
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'We\'ll verify your identity before proceeding.',
                            style: smallHintStyle,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onErrorContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.outlineVariant
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _message!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryDark,
                                AppTheme.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Send reset link',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.send_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: Icon(
                              Icons.login_rounded,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                            label: Text(
                              'Back to login',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primary,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Divider(
                          height: 1,
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                              children: [
                                const TextSpan(text: 'Need help? '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: _openSupport,
                                    child: Text(
                                      'Contact support',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: -128,
            bottom: -128,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.1,
                child: Container(
                  width: 256,
                  height: 256,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primaryContainer,
                        blurRadius: 64,
                        spreadRadius: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
