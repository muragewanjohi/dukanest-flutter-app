import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../config/app_config.dart';
import '../../../core/auth/google_sign_in_config.dart';
import '../data/business_types.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _industryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Dio _publicDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.publicApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json',
    ),
  );

  Timer? _subdomainDebounce;
  int _subdomainRequestId = 0;

  String? _selectedBusinessType;
  String _selectedCountryCode = 'Kenya (+254)';
  bool _isLoading = false;
  bool _showEmailPasswordForm = false;
  bool _didAttemptSubmit = false;

  String? _googleEmail;
  String? _googleIdToken;
  String? _authErrorMessage;

  bool _isCheckingSubdomain = false;
  bool? _isSubdomainAvailable;
  String? _subdomainMessage;
  bool _subdomainCheckFailed = false;

  @override
  void dispose() {
    _subdomainDebounce?.cancel();
    _storeNameController.dispose();
    _storeUrlController.dispose();
    _industryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              '(same ID as in Supabase -> Auth -> Google).',
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
      if (!mounted) return;
      setState(() {
        _googleEmail = account.email;
        _googleIdToken = auth.idToken;
      });
      if (auth.idToken == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google did not return an ID token. Check serverClientId / OAuth setup.',
            ),
          ),
        );
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

  void _toggleEmailPasswordSection() {
    setState(() {
      _showEmailPasswordForm = !_showEmailPasswordForm;
      _authErrorMessage = null;
      if (!_showEmailPasswordForm) {
        _emailController.clear();
        _passwordController.clear();
      }
    });
  }

  bool _hasAuthForSubmit() {
    final googleOk = _googleIdToken != null && _googleIdToken!.isNotEmpty;
    final emailOk = _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
    return googleOk || emailOk;
  }

  void _onStoreNameChanged(String value) {
    final cleanedName = value.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');
    if (cleanedName != value) {
      _storeNameController.value = TextEditingValue(
        text: cleanedName,
        selection: TextSelection.collapsed(offset: cleanedName.length),
      );
    }

    final currentSlug = _slugify(cleanedName);
    _storeUrlController.text = currentSlug;
    _storeUrlController.selection =
        TextSelection.collapsed(offset: _storeUrlController.text.length);
    _scheduleSubdomainCheck(currentSlug);
    setState(() {});
  }

  void _onStoreUrlChanged(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (normalized != value) {
      _storeUrlController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    _scheduleSubdomainCheck(normalized);
  }

  void _scheduleSubdomainCheck(String subdomain) {
    _subdomainDebounce?.cancel();
    if (subdomain.trim().isEmpty) {
      setState(() {
        _isCheckingSubdomain = false;
        _isSubdomainAvailable = null;
        _subdomainMessage = null;
        _subdomainCheckFailed = false;
      });
      return;
    }

    _subdomainDebounce = Timer(const Duration(milliseconds: 400), () {
      _checkSubdomainAvailability(subdomain.trim());
    });
  }

  Future<void> _checkSubdomainAvailability(String subdomain) async {
    final requestId = ++_subdomainRequestId;
    final requestUrl = Uri.parse(
      '${AppConfig.publicApiBaseUrl}/api/tenants/check-subdomain',
    ).replace(
      queryParameters: {'subdomain': subdomain},
    );
    if (mounted) {
      setState(() {
        _isCheckingSubdomain = true;
        _subdomainMessage = 'Checking availability...';
        _subdomainCheckFailed = false;
      });
    }
    if (kDebugMode) {
      debugPrint('[register] checking subdomain -> $requestUrl');
    }

    try {
      final response = await _publicDio.get(
        '/api/tenants/check-subdomain',
        queryParameters: {'subdomain': subdomain},
      );

      if (!mounted || requestId != _subdomainRequestId) return;

      final data = response.data;
      final available = data is Map<String, dynamic>
          ? data['available'] == true
          : false;
      setState(() {
        _isCheckingSubdomain = false;
        _isSubdomainAvailable = available;
        _subdomainMessage =
            available ? 'Subdomain is available' : 'Subdomain is already taken';
        _subdomainCheckFailed = false;
      });
      if (kDebugMode) {
        debugPrint(
          '[register] subdomain result -> available=$available status=${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (!mounted || requestId != _subdomainRequestId) return;
      final dynamic body = e.response?.data;
      String message = 'Could not verify subdomain right now';
      if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      }
      setState(() {
        _isCheckingSubdomain = false;
        _isSubdomainAvailable = null;
        _subdomainMessage = message;
        _subdomainCheckFailed = true;
      });
      if (kDebugMode) {
        debugPrint(
          '[register] subdomain check failed -> status=${e.response?.statusCode} message=$message error=${e.message}',
        );
      }
    } catch (_) {
      if (!mounted || requestId != _subdomainRequestId) return;
      setState(() {
        _isCheckingSubdomain = false;
        _isSubdomainAvailable = null;
        _subdomainMessage = 'Could not verify subdomain right now';
        _subdomainCheckFailed = true;
      });
      if (kDebugMode) {
        debugPrint('[register] subdomain check failed -> unknown error');
      }
    }
  }

  void _submit() {
    setState(() {
      _didAttemptSubmit = true;
      _authErrorMessage = null;
    });

    if (_isCheckingSubdomain) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for subdomain check to finish')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedBusinessType == null || _selectedBusinessType!.isEmpty) {
      return;
    }

    if (!_hasAuthForSubmit()) {
      setState(() {
        _authErrorMessage =
            'Connect with Google or enter email and password to continue.';
      });
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final slug = _storeUrlController.text.trim();
      final fallbackEmail = '${slug.isEmpty ? 'owner' : slug}@dukanest.demo';
      final emailForDemo = _googleEmail?.trim().isNotEmpty == true
          ? _googleEmail!.trim()
          : _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : fallbackEmail;
      ref.read(authProvider.notifier).loginWithDemoUser(email: emailForDemo);
      setState(() => _isLoading = false);
      context.go('/dashboard');
    });
  }

  Widget _buildFieldLabel(String label, {String? hint}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Color _subdomainStatusColor(ThemeData theme) {
    if (_isCheckingSubdomain) return theme.colorScheme.primary;
    if (_subdomainCheckFailed) return Colors.orange.shade700;
    if (_isSubdomainAvailable == true) return Colors.green.shade700;
    if (_isSubdomainAvailable == false) return theme.colorScheme.error;
    return theme.colorScheme.onSurfaceVariant;
  }

  String _slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.secondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                autovalidateMode: _didAttemptSubmit
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo_with_name.png',
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Start your 14-day free trial',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: SvgPicture.asset(
                        'assets/images/google_icon.svg',
                        height: 20,
                        width: 20,
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    if (_googleEmail != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Google connected: $_googleEmail',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_didAttemptSubmit && _authErrorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _authErrorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: InkWell(
                            onTap: _isLoading ? null : _toggleEmailPasswordSection,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Text(
                                _showEmailPasswordForm
                                    ? 'Use Google instead'
                                    : 'Or continue with email and password',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    if (_showEmailPasswordForm) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Admin Email',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'admin@example.com',
                                suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                              ),
                              validator: (value) {
                                if (!_showEmailPasswordForm) return null;
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Please enter your email';
                                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(v)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Password',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: '••••••••',
                                suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                              ),
                              validator: (value) {
                                if (!_showEmailPasswordForm) return null;
                                final v = value ?? '';
                                if (v.isEmpty) return 'Please enter a password';
                                if (v.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                                    !RegExp(r'\d').hasMatch(v)) {
                                  return 'Password must contain letters and numbers';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    _buildFieldLabel('Store Name'),
                    TextFormField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(
                        hintText: 'My Store',
                        suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                      ),
                      onChanged: _onStoreNameChanged,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Please enter store name';
                        if (v.length < 2) return 'Store name must be at least 2 characters';
                        if (!RegExp(r'^[A-Za-z0-9 ]+$').hasMatch(v)) {
                          return 'Use letters, numbers, and spaces only';
                        }
                        return null;
                      },
                    ),
                    _buildFieldLabel('Store URL'),
                    TextFormField(
                      controller: _storeUrlController,
                      decoration: const InputDecoration(hintText: 'my-store'),
                      onChanged: _onStoreUrlChanged,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Please enter store URL';
                        if (v.length < 3) return 'Subdomain must be at least 3 characters';
                        if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v)) {
                          return 'Use lowercase letters, numbers, and hyphens';
                        }
                        if (_isSubdomainAvailable == false) {
                          return 'Subdomain is unavailable';
                        }
                        if (_subdomainCheckFailed) {
                          return 'Unable to verify subdomain. Check API connection.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(text: 'dukanest.com/'),
                          TextSpan(
                            text: _storeUrlController.text.isEmpty
                                ? 'my-store'
                                : _storeUrlController.text,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subdomainMessage ?? 'Choose a unique subdomain',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _subdomainStatusColor(theme),
                        fontWeight: _isCheckingSubdomain ? FontWeight.w600 : null,
                      ),
                    ),
                    _buildFieldLabel('Business Type'),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _didAttemptSubmit && _selectedBusinessType == null
                              ? colorScheme.error
                              : Colors.transparent,
                        ),
                      ),
                      child: DropdownMenu<String>(
                        initialSelection: _selectedBusinessType,
                        hintText: 'Select your business type',
                        expandedInsets: EdgeInsets.zero,
                        inputDecorationTheme: const InputDecorationTheme(
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        dropdownMenuEntries: kBusinessTypeOptions.map((opt) {
                          return DropdownMenuEntry<String>(
                            value: opt.value,
                            label: opt.value,
                            labelWidget: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.value,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    opt.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onSelected: (v) => setState(() => _selectedBusinessType = v),
                      ),
                    ),
                    if (_didAttemptSubmit && _selectedBusinessType == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Please select a business type',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    _buildFieldLabel('What are you selling?'),
                    TextFormField(
                      controller: _industryController,
                      decoration: const InputDecoration(
                        hintText: 'What are you selling',
                        suffixIcon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return null;
                        if (v.length < 2) return 'Please enter at least 2 characters';
                        if (!RegExp(r'^[A-Za-z0-9 &,-]+$').hasMatch(v)) {
                          return 'Contains unsupported characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We will customize your store based on what you are selling',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "We'll add demo products so you can see how your store looks right away",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildFieldLabel(
                      'Store phone number',
                      hint:
                          'Receive SMS alerts when customers place orders so you never miss a sale. You can add or change this anytime in settings.',
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownMenu<String>(
                            initialSelection: _selectedCountryCode,
                            expandedInsets: EdgeInsets.zero,
                            inputDecorationTheme: const InputDecorationTheme(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            dropdownMenuEntries:
                                ['Kenya (+254)', 'Uganda (+256)', 'Tz (+255)'].map((e) {
                              return DropdownMenuEntry(value: e, label: e);
                            }).toList(),
                            onSelected: (v) => setState(() => _selectedCountryCode = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(hintText: '712 345 678'),
                            validator: (value) {
                              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                              if (digits.isEmpty) return 'Enter phone number';
                              if (digits.length < 9 || digits.length > 12) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          children: [
                            const TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [colorScheme.primaryContainer, colorScheme.primary],
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create My Store'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
