import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../core/auth/google_sign_in_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/token_storage.dart';
import '../data/business_types.dart';
import '../data/country_dial_codes.dart';
import '../providers/auth_provider.dart';
import '../widgets/onboarding_step_header.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  /// Basic plan row in `price_plans` — must match backend.
  static const _defaultRegisterPlanId =
      'dd4b8f9e-3fe4-4da1-ad37-fb4671f43bdd';

  /// One form per onboarding step so `validate()` only runs fields on that step.
  final List<GlobalKey<FormState>> _formKeys =
      List<GlobalKey<FormState>>.generate(4, (_) => GlobalKey<FormState>());

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
  /// Step index 0–3: Account → Store URL → Business → Contact & submit.
  int _step = 0;
  bool _didAttemptBusinessType = false;

  String? _googleEmail;
  String? _googleIdToken;
  String? _googleAccessToken;
  String? _authErrorMessage;

  bool _isCheckingSubdomain = false;
  bool? _isSubdomainAvailable;
  String? _subdomainMessage;
  bool _subdomainCheckFailed = false;
  int _creationStageIndex = 0;
  Timer? _creationStageTimer;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  static final Uri _privacyPolicyUri = Uri.parse('https://www.dukanest.com/privacy-policy');
  static final Uri _termsOfServiceUri = Uri.parse(
    'https://www.dukanest.com/terms-of-service',
  );

  static const List<String> _creationStages = [
    'Creating your store workspace...',
    'Setting up storefront basics...',
    'Applying your business profile...',
    'Finalizing account and access...',
  ];

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = () => _openExternalUrl(_termsOfServiceUri);
    _privacyRecognizer = TapGestureRecognizer()..onTap = () => _openExternalUrl(_privacyPolicyUri);
  }

  @override
  void dispose() {
    _subdomainDebounce?.cancel();
    _creationStageTimer?.cancel();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _storeNameController.dispose();
    _storeUrlController.dispose();
    _industryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openExternalUrl(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
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
      final token = auth.idToken;
      setState(() {
        _googleIdToken = token;
        _googleAccessToken = null;
        // Only show "connected" when we actually have a usable token.
        _googleEmail = token == null ? null : account.email;
      });
      if (token == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google sign-in succeeded but no ID token was returned. Please try again.',
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

  String _countryIsoFromSelection(String selected) {
    final country = selected.split(' (').first.trim();
    const isoByCountry = <String, String>{
      'Kenya': 'KE',
      'Uganda': 'UG',
      'Tanzania': 'TZ',
      'United States': 'US',
      'United Kingdom': 'GB',
      'South Africa': 'ZA',
      'Nigeria': 'NG',
      'India': 'IN',
      'Canada': 'CA',
      'Australia': 'AU',
    };
    return isoByCountry[country] ?? 'KE';
  }

  String _phoneDialCodeFromSelection(String selected) {
    final match = RegExp(r'\((\+\d+(?:-\d+)*)\)').firstMatch(selected);
    return match?.group(1) ?? '+254';
  }

  String _storeUrlFromSubdomain(String subdomain) {
    final host = Uri.tryParse(AppConfig.publicApiBaseUrl)?.host ?? 'dukanest.com';
    final rootHost = host.startsWith('www.') ? host.substring(4) : host;
    return 'https://$subdomain.$rootHost';
  }

  void _startCreationProgress() {
    _creationStageTimer?.cancel();
    _creationStageIndex = 0;
    _creationStageTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() {
        if (_creationStageIndex < _creationStages.length - 1) {
          _creationStageIndex += 1;
        }
      });
    });
  }

  void _stopCreationProgress() {
    _creationStageTimer?.cancel();
    _creationStageTimer = null;
  }

  Future<bool> _attemptPostRegistrationSignIn({
    required bool isGooglePath,
    required String adminEmail,
  }) async {
    if (isGooglePath) {
      if (_googleIdToken == null || _googleIdToken!.isEmpty) return false;
      await ref.read(authProvider.notifier).googleSignIn(
            _googleIdToken!,
            accessToken: _googleAccessToken,
          );
    } else {
      await ref.read(authProvider.notifier).login(
            adminEmail,
            _passwordController.text,
          );
    }

    final auth = ref.read(authProvider);
    return auth.status == AuthStatus.authenticated ||
        auth.status == AuthStatus.awaitingMfa;
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

  Future<void> _submit() async {
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

    for (final key in _formKeys) {
      if (key.currentState != null && !key.currentState!.validate()) {
        return;
      }
    }

    if (_selectedBusinessType == null || _selectedBusinessType!.isEmpty) {
      setState(() => _didAttemptBusinessType = true);
      return;
    }

    if (!_hasAuthForSubmit()) {
      setState(() {
        _authErrorMessage =
            'Connect with Google or enter email and password to continue.';
      });
      return;
    }

    final slug = _storeUrlController.text.trim();
    final isGooglePath = _googleIdToken != null && _googleIdToken!.isNotEmpty;
    final adminEmail = isGooglePath
        ? (_googleEmail?.trim() ?? '')
        : _emailController.text.trim();
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final countryIso = _countryIsoFromSelection(_selectedCountryCode);
    final dialCode = _phoneDialCodeFromSelection(_selectedCountryCode);
    final normalizedPhone = phoneDigits.startsWith('0')
        ? '$dialCode${phoneDigits.substring(1)}'
        : '$dialCode$phoneDigits';

    setState(() => _isLoading = true);
    _startCreationProgress();
    try {
      final trialEndsAt = DateTime.now()
          .toUtc()
          .add(const Duration(days: 14))
          .toIso8601String();

      final payload = <String, dynamic>{
        'name': _storeNameController.text.trim(),
        'subdomain': slug,
        'adminEmail': adminEmail,
        'adminPhone': normalizedPhone,
        'adminPhoneCountry': countryIso,
        'authProvider': isGooglePath ? 'google' : 'email',
        'businessType': _selectedBusinessType,
        'selling': _industryController.text.trim().isEmpty
            ? _selectedBusinessType
            : _industryController.text.trim(),
        'planId': _defaultRegisterPlanId,
        // Matches tenant `expire_date` / admin tenant update contract; ISO-8601.
        'expire_date': trialEndsAt,
        // Trigger onboarding starter/demo seed on backend.
        'includeDemoContent': true,
        'includeDemoAttributes': true,
      };
      if (!isGooglePath) {
        payload['adminPassword'] = _passwordController.text;
      } else {
        // Backend implementations vary on field names for Google token exchange.
        payload['idToken'] = _googleIdToken;
        payload['googleIdToken'] = _googleIdToken;
        if (_googleAccessToken != null && _googleAccessToken!.isNotEmpty) {
          payload['googleAccessToken'] = _googleAccessToken;
          payload['accessToken'] = _googleAccessToken;
        }
      }

      final registerResp = await _publicDio.post(
        '/api/tenants/register',
        data: payload,
        options: Options(
          // Registration can enqueue starter/demo setup and take >10s.
          receiveTimeout: const Duration(seconds: 90),
          connectTimeout: const Duration(seconds: 20),
          headers: isGooglePath
              ? <String, dynamic>{
                  'Authorization': 'Bearer $_googleIdToken',
                  'X-Google-Auth-Token': _googleIdToken,
                  if (_googleAccessToken != null && _googleAccessToken!.isNotEmpty)
                    'X-Google-Access-Token': _googleAccessToken,
                }
              : null,
        ),
      );
      if (kDebugMode) {
        debugPrint(
          '[register] register response -> status=${registerResp.statusCode} body=${registerResp.data}',
        );
      }

      final ok = registerResp.statusCode == 201 ||
          (registerResp.data is Map<String, dynamic> &&
              registerResp.data['success'] == true);
      if (!ok) {
        throw DioException(
          requestOptions: registerResp.requestOptions,
          response: registerResp,
          type: DioExceptionType.badResponse,
          message: 'Registration failed',
        );
      }

      if (registerResp.data is Map<String, dynamic>) {
        final registerData = registerResp.data as Map<String, dynamic>;
        final tenantRaw = registerData['tenant'];
        if (tenantRaw is Map) {
          final tenant = Map<String, dynamic>.from(tenantRaw);
          final storeName = (tenant['name'] ?? _storeNameController.text.trim()).toString();
          final storeSubdomain = (tenant['subdomain'] ?? slug).toString();
          final storeUrl = _storeUrlFromSubdomain(storeSubdomain);
          await ref.read(tokenStorageProvider).saveStoreIdentity(
                name: storeName,
                subdomain: storeSubdomain,
                storeUrl: storeUrl,
                logoUrl: (tenant['logoUrl'] ?? tenant['logo'] ?? tenant['storeLogo'] ?? tenant['logo_url'])
                    ?.toString(),
              );
        }
      }

      await _attemptPostRegistrationSignIn(
        isGooglePath: isGooglePath,
        adminEmail: adminEmail,
      );

      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.authenticated ||
          auth.status == AuthStatus.awaitingMfa) {
        // Router redirect handles /dashboard or /mfa.
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store created. Please sign in to continue.'),
          ),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;

      if (isTimeout) {
        try {
          final signedIn = await _attemptPostRegistrationSignIn(
            isGooglePath: isGooglePath,
            adminEmail: adminEmail,
          );
          if (signedIn && mounted) {
            context.go('/dashboard');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Store creation took longer than expected, but your account is ready.',
                ),
              ),
            );
            return;
          }
        } catch (_) {
          // Fall through to user-facing timeout guidance below.
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[register] register failed -> status=${e.response?.statusCode} body=$body message=${e.message}',
        );
      }
      String message = 'Could not create store. Please try again.';
      if (isTimeout) {
        message =
            'Store setup is taking longer than expected. Your store may already be created - please try signing in.';
      }
      if (body is Map<String, dynamic>) {
        if (body['message'] is String && (body['message'] as String).isNotEmpty) {
          message = body['message'] as String;
        } else if (body['error'] is Map &&
            (body['error'] as Map)['message'] is String) {
          message = (body['error'] as Map)['message'] as String;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while creating your store.'),
        ),
      );
    } finally {
      _stopCreationProgress();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static const List<String> _stepTitles = [
    'Account',
    'Store address',
    'Business profile',
    'Contact',
  ];

  void _handleAppBarBack() {
    if (_step <= 0) {
      context.pop();
      return;
    }
    _decrementStep();
  }

  void _decrementStep() {
    if (_step <= 0) return;
    setState(() {
      _step -= 1;
      _authErrorMessage = null;
    });
  }

  void _goNextFromStep() {
    if (_step == 0) {
      setState(() => _authErrorMessage = null);
      if (!_formKeys[0].currentState!.validate()) return;
      if (!_hasAuthForSubmit()) {
        setState(() {
          _authErrorMessage =
              'Connect with Google or enter email and password to continue.';
        });
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_isCheckingSubdomain) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait for subdomain check to finish')),
        );
        return;
      }
      if (!_formKeys[1].currentState!.validate()) return;
      if (_isSubdomainAvailable == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an available store URL to continue.')),
        );
        return;
      }
      if (_subdomainCheckFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fix the store URL issue or check your connection before continuing.'),
          ),
        );
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      if (_selectedBusinessType == null || _selectedBusinessType!.isEmpty) {
        setState(() => _didAttemptBusinessType = true);
        return;
      }
      if (!_formKeys[2].currentState!.validate()) return;
      setState(() => _step = 3);
    }
  }

  Widget _buildLogo(ThemeData theme) {
    return Center(
      child: Image.asset(
        'assets/images/logo_with_name.png',
        height: 48,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildStepProgress(ThemeData theme, ColorScheme colorScheme) {
    // Stitch "Registration: Business Profile" — uppercase step label + segmented gradient bar.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STEP ${_step + 1} OF 4',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            Text(
              _stepTitles[_step],
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(4, (i) {
            final done = i <= _step;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: done
                      ? const LinearGradient(
                          colors: [AppTheme.primaryDark, AppTheme.primary],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: done ? null : colorScheme.surfaceContainerHigh,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Stitch-style uppercase field label (Business Profile screen).
  Widget _stitchFieldCapsLabel(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
      ),
    );
  }

  InputDecoration _stitchFilledInputDecoration(ColorScheme colorScheme, {String? hintText}) {
    final r = BorderRadius.circular(12);
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.35), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  String _tailoredBlurbForBusinessType() {
    final t = _selectedBusinessType ?? '';
    if (t.isEmpty) {
      return '';
    }
    if (t.contains('Fashion') || t.contains('Clothing')) {
      return "we'll prioritize size variants and gallery-friendly layouts in your store editor.";
    }
    if (t.contains('Electronics') || t.contains('Gadget')) {
      return "we'll emphasize spec fields and comparison-friendly product layouts.";
    }
    if (t.contains('Groceries') ||
        t.contains('Food') ||
        t.contains('Bakery') ||
        t.contains('Restaurant')) {
      return "we'll surface variants and fulfillment patterns suited to food businesses.";
    }
    if (t.contains('Beauty')) {
      return "we'll highlight variant-friendly SKUs and rich imagery for your catalog.";
    }
    if (t.contains('Home') || t.contains('Kitchen')) {
      return "we'll lean into dimensions, variants, and lifestyle imagery in your editor.";
    }
    if (t.contains('Health') || t.contains('Pharmacy')) {
      return "we'll keep compliance-friendly fields and clear product labeling in mind.";
    }
    if (t.contains('Automotive') || t.contains('Hardware') || t.contains('Sports')) {
      return "we'll favor structured attributes and specification-friendly product pages.";
    }
    return "we'll tune dashboard shortcuts and starter suggestions around your category.";
  }

  Future<void> _openBusinessTypePicker() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final sheetH = MediaQuery.sizeOf(ctx).height * 0.72;
        String query = '';
        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final normalizedQuery = query.trim().toLowerCase();
                final filtered = normalizedQuery.isEmpty
                    ? kBusinessTypeOptions
                    : kBusinessTypeOptions.where((opt) {
                        return opt.value.toLowerCase().contains(normalizedQuery) ||
                            opt.description.toLowerCase().contains(normalizedQuery);
                      }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        'Select your industry',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        onChanged: (value) => setSheetState(() => query = value),
                        decoration: InputDecoration(
                          hintText: 'Search industry',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                        itemBuilder: (context, i) {
                          final opt = filtered[i];
                          final sel = _selectedBusinessType == opt.value;
                          return ListTile(
                            title: Text(
                              opt.value,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                color: colorScheme.secondary,
                              ),
                            ),
                            subtitle: Text(
                              opt.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            selected: sel,
                            selectedTileColor: colorScheme.primary.withValues(alpha: 0.06),
                            onTap: () {
                              setState(() {
                                _selectedBusinessType = opt.value;
                                _didAttemptBusinessType = false;
                              });
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCountryCodePicker() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final sheetH = MediaQuery.sizeOf(ctx).height * 0.72;
        String query = '';
        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final normalizedQuery = query.trim().toLowerCase();
                final filtered = normalizedQuery.isEmpty
                    ? kCountryDialCodes
                    : kCountryDialCodes
                          .where((item) => item.toLowerCase().contains(normalizedQuery))
                          .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        'Select country code',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        onChanged: (value) => setSheetState(() => query = value),
                        decoration: InputDecoration(
                          hintText: 'Search country',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                        itemBuilder: (context, i) {
                          final value = filtered[i];
                          final isSelected = _selectedCountryCode == value;
                          return ListTile(
                            title: Text(
                              value,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: colorScheme.secondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: colorScheme.primary.withValues(alpha: 0.06),
                            onTap: () {
                              setState(() => _selectedCountryCode = value);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _stitchPrimaryGradientButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: enabled
            ? const LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: enabled ? null : colorScheme.surfaceContainerHigh,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF0C0528).withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: enabled ? Colors.white : colorScheme.onSurfaceVariant,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: enabled ? Colors.white : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _registerStep0Account(ThemeData theme, ColorScheme colorScheme) {
    return Form(
      key: _formKeys[0],
      autovalidateMode:
          _didAttemptSubmit ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingStepHeader(title: 'Start your 14-day free trial'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: SvgPicture.asset(
              'assets/images/google_icon.svg',
              height: 20,
              width: 20,
            ),
            label: const Text('Continue with Google'),
            style: ElevatedButton.styleFrom(
              foregroundColor: colorScheme.secondary,
              backgroundColor: colorScheme.surface,
              disabledForegroundColor: colorScheme.onSurfaceVariant,
              disabledBackgroundColor: colorScheme.surfaceContainerHigh,
              elevation: 1.5,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
              minimumSize: const Size(double.infinity, 56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.32),
                ),
              ),
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
          if (_authErrorMessage != null) ...[
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
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
        ],
      ),
    );
  }

  Widget _registerStep1Store(ThemeData theme, ColorScheme colorScheme) {
    return Form(
      key: _formKeys[1],
      autovalidateMode:
          _didAttemptSubmit ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingStepHeader(
            title: 'Choose your store name and URL',
            description: 'You can change these later in settings.',
          ),
          const SizedBox(height: 20),
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
        ],
      ),
    );
  }

  Widget _registerStep2Business(ThemeData theme, ColorScheme colorScheme) {
    final showBizError =
        (_didAttemptBusinessType || _didAttemptSubmit) && _selectedBusinessType == null;
    return Form(
      key: _formKeys[2],
      autovalidateMode:
          _didAttemptSubmit ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stitch: Registration — Business Profile (logo + stepper unchanged above).
          const OnboardingStepHeader(
            title: 'Tell us about your business',
            description:
                "We'll use these details to pre-configure your dashboard and store settings.",
          ),
          const SizedBox(height: 40),
          _stitchFieldCapsLabel('Business type', colorScheme),
          Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isLoading ? null : _openBusinessTypePicker,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showBizError ? colorScheme.error : Colors.transparent,
                    width: showBizError ? 1.5 : 0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedBusinessType ?? 'Select your industry',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _selectedBusinessType == null
                              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: colorScheme.outline, size: 26),
                  ],
                ),
              ),
            ),
          ),
          if (showBizError) ...[
            const SizedBox(height: 8),
            Text(
              'Please select a business type',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _stitchFieldCapsLabel('What are you selling?', colorScheme),
          TextFormField(
            controller: _industryController,
            decoration: _stitchFilledInputDecoration(
              colorScheme,
              hintText: 'e.g. Leather handbags',
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
          const SizedBox(height: 6),
          Text(
            'Specific product names help our AI generate better SEO tags.',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              height: 1.35,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.inversePrimary.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tailored For You',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_selectedBusinessType == null || _selectedBusinessType!.isEmpty)
                        Text(
                          'Choose an industry to see how we pre-configure your dashboard and editor.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            height: 1.45,
                          ),
                        )
                      else
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              height: 1.45,
                            ),
                            children: [
                              const TextSpan(text: 'By selecting '),
                              TextSpan(
                                text: _selectedBusinessType,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: ', ${_tailoredBlurbForBusinessType()}'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _registerStep3Contact(ThemeData theme, ColorScheme colorScheme) {
    return Form(
      key: _formKeys[3],
      autovalidateMode:
          _didAttemptSubmit ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingStepHeader(
            title: 'Contact & alerts',
            description: 'We use your phone for order SMS alerts.',
          ),
          const SizedBox(height: 20),
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
                child: Material(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _isLoading ? null : _openCountryCodePicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCountryCode,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            color: colorScheme.outline,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
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
          const SizedBox(height: 28),
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
                    recognizer: _termsRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: _privacyRecognizer,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: kToolbarHeight,
        foregroundColor: colorScheme.secondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleAppBarBack,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLogo(theme),
                            const SizedBox(height: 16),
                            _buildStepProgress(theme, colorScheme),
                            const SizedBox(height: 16),
                            Expanded(
                              child: IndexedStack(
                                index: _step,
                                sizing: StackFit.expand,
                                children: [
                                  SingleChildScrollView(
                                    child: _registerStep0Account(theme, colorScheme),
                                  ),
                                  SingleChildScrollView(
                                    child: _registerStep1Store(theme, colorScheme),
                                  ),
                                  SingleChildScrollView(
                                    child: _registerStep2Business(theme, colorScheme),
                                  ),
                                  SingleChildScrollView(
                                    child: _registerStep3Contact(theme, colorScheme),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _step < 3
                          ? (_step == 0
                              ? Row(
                                  children: [
                                    const Spacer(flex: 1),
                                    Expanded(
                                      flex: 2,
                                      child: _stitchPrimaryGradientButton(
                                        onPressed: _isLoading ? null : _goNextFromStep,
                                        child: const Text('Next step'),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextButton(
                                        onPressed: _isLoading ? null : _decrementStep,
                                        style: TextButton.styleFrom(
                                          foregroundColor: colorScheme.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Back',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: _stitchPrimaryGradientButton(
                                        onPressed: _isLoading ? null : _goNextFromStep,
                                        child: const Text('Next step'),
                                      ),
                                    ),
                                  ],
                                ))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextButton(
                                    onPressed: _isLoading ? null : _decrementStep,
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Back',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _stitchPrimaryGradientButton(
                                    onPressed: _isLoading ? null : _submit,
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
                              ],
                            ),
                    ),
                  ),
                ),
              ],
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
                              _creationStages[_creationStageIndex],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This can take about 40-60 seconds.',
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
