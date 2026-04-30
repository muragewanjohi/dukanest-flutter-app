import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import '../../../config/app_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/google_sign_in_config.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _supportEmail = 'support@dukanest.com';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _signInStageIndex = 0;
  Timer? _signInStageTimer;

  static const List<String> _signInStages = [
    'Signing you in...',
    'Loading your store dashboard...',
    'Finalizing your session...',
  ];

  void _startSignInProgress() {
    _signInStageTimer?.cancel();
    _signInStageIndex = 0;
    _signInStageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        if (_signInStageIndex < _signInStages.length - 1) {
          _signInStageIndex += 1;
        }
      });
    });
  }

  void _stopSignInProgress() {
    _signInStageTimer?.cancel();
    _signInStageTimer = null;
    _signInStageIndex = 0;
  }

  @override
  void dispose() {
    _signInStageTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _startSignInProgress();
    });
    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      final status = ref.read(authProvider).status;
      if (mounted) {
        if (status == AuthStatus.authenticated) {
          context.go('/dashboard');
        } else if (status == AuthStatus.awaitingMfa) {
          context.go('/mfa');
        }
      }
    } finally {
      _stopSignInProgress();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (androidNeedsGoogleServerClientId() &&
        AppConfig.googleServerClientId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add your Google Web client ID: '
              'flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com '
              '(same ID as in Supabase → Auth → Google).',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _startSignInProgress();
    });
    try {
      await ensureGoogleSignInInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final auth = account.authentication;
      if (auth.idToken != null) {
        await ref.read(authProvider.notifier).googleSignIn(auth.idToken!);
        final status = ref.read(authProvider).status;
        if (mounted && status == AuthStatus.authenticated) {
          context.go('/dashboard');
        }
      }
    } on GoogleSignInException catch (e) {
      if (mounted &&
          e.code != GoogleSignInExceptionCode.canceled &&
          e.code != GoogleSignInExceptionCode.interrupted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In failed: ${e.description}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign In failed: $e')),
        );
      }
    } finally {
      _stopSignInProgress();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFieldLabel(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }

  bool _isTenantUnavailableError(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('tenant account is deleted or unavailable') ||
        lower.contains('tenant is deleted or unavailable') ||
        lower.contains('tenant unavailable') ||
        lower.contains('tenant account is deleted') ||
        lower.contains('store associated') ||
        lower.contains('store not found') ||
        lower.contains('tenant not found');
  }

  String _friendlyAuthError(String raw) {
    final message = raw.trim();
    final lower = message.toLowerCase();
    if (_isTenantUnavailableError(message)) {
      return "We can't locate a store associated with your email.";
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (lower.contains('connecttimeout') ||
        lower.contains('timed out') ||
        lower.contains('connection took longer')) {
      return 'Request timed out. Please try again in a moment.';
    }
    if (lower.contains('missing or invalid bearer token') ||
        lower.contains('unauthorized') ||
        lower.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (message.length > 180) {
      return 'Could not sign in right now. Please try again.';
    }
    return message;
  }

  Future<void> _contactSupport() async {
    final email = _emailController.text.trim();
    final body = [
      'Hello DukaNest Support,',
      '',
      "I can't locate a store associated with my email.",
      if (email.isNotEmpty) 'Login email: $email',
      '',
      'Please help me recover access or confirm the next steps.',
    ].join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Help locating my DukaNest store',
        'body': body,
      },
    );

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted || launched) return;
    } catch (_) {}

    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support email copied: support@dukanest.com'),
      ),
    );
  }

  Widget _buildAuthErrorCard(String rawError) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTenantUnavailable = _isTenantUnavailableError(rawError);

    if (!isTenantUnavailable) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _friendlyAuthError(rawError),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onErrorContainer,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.storefront_outlined, color: colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "We can't locate a store associated with your email.",
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can create a new store or contact support if you believe this is a mistake.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer
                            .withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => context.go('/register'),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Create a new store'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isLoading ? null : _contactSupport,
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: const Text('Contact support'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 760;
                final horizontalPadding = compact ? 20.0 : 24.0;
                final verticalPadding = compact ? 16.0 : 24.0;
                final logoHeight = compact ? 44.0 : 56.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight - (verticalPadding * 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Logo
                                Center(
                                  child: Image.asset(
                                    'assets/images/logo_with_name.png',
                                    height: logoHeight,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(height: compact ? 20 : 32),
                                Text(
                                  'Welcome back, Owner',
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.secondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to manage your shop.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: compact ? 16 : 24),

                                // Google — elevated, high-contrast secondary CTA (distinct from email form).
                                Material(
                                  elevation: 1,
                                  shadowColor:
                                      colorScheme.shadow.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  color: colorScheme.surface,
                                  child: InkWell(
                                    onTap:
                                        _isLoading ? null : _handleGoogleSignIn,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                          width: 1.0,
                                        ),
                                        color:
                                            colorScheme.surfaceContainerLowest,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: compact ? 14 : 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/images/google_icon.svg',
                                              height: 22,
                                              width: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Continue with Google',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: compact ? 14 : 20),
                                Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.5))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text('or',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant)),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.5))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Continue with Google or enter a valid email and password.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: compact ? 14 : 20),

                                if (authState.error != null) ...[
                                  _buildAuthErrorCard(authState.error!),
                                  SizedBox(height: compact ? 12 : 16),
                                ],

                                _buildFieldLabel('Email'),
                                TextFormField(
                                  controller: _emailController,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    hintText: 'you@example.com',
                                    prefixIcon: Icon(Icons.email_outlined),
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
                                SizedBox(height: compact ? 12 : 16),

                                _buildFieldLabel('Password'),
                                TextFormField(
                                  controller: _passwordController,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  onChanged: (_) => setState(() {}),
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.go('/reset-password'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                    ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                SizedBox(height: compact ? 10 : 14),

                                // Signature Gradient CTA Button: Sign in to Dashboard
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: !_isLoading
                                        ? [
                                            BoxShadow(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            )
                                          ]
                                        : null,
                                    gradient: !_isLoading
                                        ? LinearGradient(
                                            colors: [
                                              colorScheme.primaryContainer,
                                              colorScheme.primary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            stops: const [0.0, 1.0],
                                            transform:
                                                const GradientRotation(2.35619),
                                          )
                                        : LinearGradient(
                                            colors: [
                                              colorScheme.primary
                                                  .withValues(alpha: 0.15),
                                              colorScheme.primary
                                                  .withValues(alpha: 0.25),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    border: !_isLoading
                                        ? null
                                        : Border.all(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.1),
                                          ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: !_isLoading
                                          ? Colors.white
                                          : colorScheme.primary
                                              .withValues(alpha: 0.6),
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.symmetric(
                                          vertical: compact ? 12 : 14),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Text('Sign in to Dashboard',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SizedBox(height: compact ? 18 : 22),

                                // Registration path: directly under primary CTA so it is not lost at the bottom edge.
                                Semantics(
                                  label:
                                      "Don't have a store? Start your free trial. Opens registration.",
                                  child: Material(
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: _isLoading
                                          ? null
                                          : () => context.go('/register'),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.storefront_outlined,
                                              color: colorScheme.primary,
                                              size: 26,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Don't have a store?",
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          colorScheme.onSurface,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Start your free trial — create your shop in minutes.',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              color: colorScheme.primary,
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_isLoading)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _signInStages[_signInStageIndex],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Please wait while we prepare your dashboard.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
