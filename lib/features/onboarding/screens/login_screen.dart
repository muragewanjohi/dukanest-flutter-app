import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../config/app_config.dart';
import '../../../core/auth/google_sign_in_config.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if(mounted) setState(() => _isLoading = false);
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

    setState(() => _isLoading = true);
    try {
      await ensureGoogleSignInInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final auth = account.authentication;
      if (auth.idToken != null) {
        await ref.read(authProvider.notifier).googleSignIn(auth.idToken!);
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

  String _friendlyAuthError(String raw) {
    final message = raw.trim();
    final lower = message.toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
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
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - (verticalPadding * 2),
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
                      style: theme.textTheme.headlineMedium?.copyWith(
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
                      elevation: 2,
                      shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.surface,
                      child: InkWell(
                        onTap: _isLoading ? null : _handleGoogleSignIn,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                            color: colorScheme.surfaceContainerLowest,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/google_icon.svg',
                                  height: 22,
                                  width: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Continue with Google',
                                  style: theme.textTheme.titleSmall?.copyWith(
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
                        Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        ),
                        Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 20),

                    if (authState.error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _friendlyAuthError(authState.error!),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 16),
                    ],

                    _buildFieldLabel('Email'),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    
                    _buildFieldLabel('Password'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/reset-password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    
                    // Signature Gradient CTA Button: Sign in to Dashboard
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ],
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer, 
                            colorScheme.primary,          
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.0, 1.0],
                          transform: const GradientRotation(2.35619),
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign in to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 22),

                    // Registration path: directly under primary CTA so it is not lost at the bottom edge.
                    Semantics(
                      label: "Don't have a store? Start your free trial. Opens registration.",
                      child: Material(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _isLoading ? null : () => context.push('/register'),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Don't have a store?",
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Start your free trial — create your shop in minutes.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}
