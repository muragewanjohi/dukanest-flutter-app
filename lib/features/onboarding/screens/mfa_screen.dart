import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/auth/auth_state.dart';
import '../providers/auth_provider.dart';

/// Email OTP / MFA step after password login — layout from Stitch
/// "MFA Verification (Updated)" (DukaNest Tenant App Plan).
class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  static final Uri _supportUri = Uri.parse('mailto:support@dukanest.com');

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[index - 1].text.length,
      );
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 1) {
      _applyPastedCode(digitsOnly);
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_code.length == 6 && !_isVerifying) {
      _submit();
    }
  }

  void _applyPastedCode(String digits) {
    final chars = digits.split('');
    for (var i = 0; i < 6; i++) {
      _controllers[i].text = i < chars.length ? chars[i] : '';
    }
    final focusIndex = chars.length >= 6 ? 5 : chars.length.clamp(0, 5);
    _focusNodes[focusIndex].requestFocus();
    if (_code.length == 6 && !_isVerifying) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final code = _code;
    if (code.length != 6) return;

    setState(() => _isVerifying = true);
    await ref.read(authProvider.notifier).verifyMfa(code);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (ref.read(authProvider).status == AuthStatus.authenticated) {
      return;
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    await ref.read(authProvider.notifier).resendMfaCode();
    if (!mounted) return;
    setState(() => _isResending = false);

    if (!mounted) return;
    if (ref.read(authProvider).error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.')),
      );
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

  Future<void> _onBack() async {
    await ref.read(authProvider.notifier).cancelMfa();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final email = authState.user?.email ?? 'your email';

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
                        onPressed: _onBack,
                        style: IconButton.styleFrom(
                          foregroundColor: AppTheme.primaryDark,
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
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 18,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Two-step verification',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verify your code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We sent a 6-digit code to $email. Enter it below to finish '
                        'signing in.',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.5,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.outlineVariant
                                .withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _digitField(context, 0),
                                const SizedBox(width: 8),
                                _digitField(context, 1),
                                const SizedBox(width: 8),
                                _digitField(context, 2),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Container(
                                    width: 8,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppTheme.outlineVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                _digitField(context, 3),
                                const SizedBox(width: 8),
                                _digitField(context, 4),
                                const SizedBox(width: 8),
                                _digitField(context, 5),
                              ],
                            ),
                            if (authState.error != null) ...[
                              const SizedBox(height: 20),
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
                                  authState.error!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
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
                                          color: AppTheme.primaryDark
                                              .withValues(alpha: 0.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (_isVerifying || _code.length != 6)
                                          ? null
                                          : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                      ),
                                      child: _isVerifying
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              'Verify and login',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      onPressed: _isResending ? null : _resend,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        foregroundColor: colorScheme.onSurface,
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: _isResending
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: colorScheme.onSurface,
                                              ),
                                            )
                                          : Text(
                                              'Resend code',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextButton.icon(
                        onPressed: _openSupport,
                        icon: Icon(
                          Icons.support_agent_rounded,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                        label: Text(
                          'Contact support',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      _decorativeCards(colorScheme),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -40,
            right: -80,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryDark.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -50,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colorScheme.secondaryContainer
                            .withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _digitField(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 56,
      child: Focus(
        onKeyEvent: (node, event) => _onKey(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '•',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.outline.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: AppTheme.surfaceContainerLowest,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
      ),
    );
  }

  Widget _decorativeCards(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.security_rounded,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 8,
                width: 180,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                width: 120,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF001C89),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0x1A4CAF50),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protected by',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Advanced Encryption',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
