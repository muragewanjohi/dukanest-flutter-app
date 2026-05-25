import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../../core/util/store_media_url.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import '../../dashboard/providers/dashboard_getting_started_provider.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../../onboarding/providers/auth_provider.dart';
import '../providers/dashboard_settings_provider.dart';

/// Store name, logo, domain, address, and support contact. Includes delete-account panel.
class StoreIdentityScreen extends ConsumerStatefulWidget {
  const StoreIdentityScreen({super.key});

  @override
  ConsumerState<StoreIdentityScreen> createState() => _StoreIdentityScreenState();
}

class _StoreIdentityScreenState extends ConsumerState<StoreIdentityScreen>
    with FormErrorHighlightMixin {
  final _storeName = TextEditingController();
  final _domain = TextEditingController();
  final _phoneLocal = TextEditingController();
  final _phone2Local = TextEditingController();
  final _phone3Local = TextEditingController();
  final _address1 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();
  final _postal = TextEditingController();
  final _supportEmail = TextEditingController();
  final _description = TextEditingController();
  final _currencyCode = TextEditingController(text: 'KES');
  final _currencySymbol = TextEditingController(text: 'KSh');
  final _decimalPlaces = TextEditingController(text: '0');
  final _thousandSeparator = TextEditingController(text: ',');
  final _decimalSeparator = TextEditingController(text: '.');
  final _picker = ImagePicker();

  List<String> _countryOptions = const [];

  String _businessType = 'Retail';
  String _sellingCategory = 'Electronics & Gadgets';

  bool _saving = false;
  String? _serverSubdomain;
  String? _logoImageUrl;
  /// Local file chosen by the user; uploaded only when they tap Save changes.
  String? _pendingLogoLocalPath;
  /// Local file kept after upload/save so preview survives until the CDN URL loads.
  String? _logoPreviewLocalPath;
  /// Bumped when the logo URL changes or after save so [CachedNetworkImage] does not show a stale bitmap if the URL is unchanged.
  int _logoCacheEpoch = 0;
  String? _lastHydratedSettingsSignature;
  bool _skipNextSettingsHydrate = false;

  bool _uploadingLogo = false;
  /// 0..1 send progress for the in-flight logo upload, or null when total size is unknown / not uploading.
  double? _logoUploadProgress;
  /// True when the user explicitly removed the logo (X button) so the next save
  /// must persist the cleared value instead of leaving the server logo untouched.
  bool _logoClearedByUser = false;

  /// Snapshot after hydrate / successful save so we can skip redundant PATCHes.
  String _baselineFormSignature = '';

  static const _businessTypeOptions = [
    'Retail',
    'Wholesale',
    'Service Provider',
    'Digital Goods',
  ];
  static const _sellingOptions = [
    'Electronics & Gadgets',
    'Fashion & Apparel',
    'Home & Living',
    'Food & Beverages',
  ];

  @override
  void dispose() {
    _storeName.dispose();
    _domain.dispose();
    _phoneLocal.dispose();
    _phone2Local.dispose();
    _phone3Local.dispose();
    _address1.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _postal.dispose();
    _supportEmail.dispose();
    _description.dispose();
    _currencyCode.dispose();
    _currencySymbol.dispose();
    _decimalPlaces.dispose();
    _thousandSeparator.dispose();
    _decimalSeparator.dispose();
    super.dispose();
  }

  void _hydrateFormFieldsFrom(Map<String, dynamic> data) {
    final store = settingsSection(data, 'store') ?? {};
    _storeName.text = settingsPick(store, ['name']);
    final sub = settingsPick(store, ['subdomain']);
    _serverSubdomain = sub.isEmpty ? null : sub;
    _domain.text = sub;
    var phone = settingsPick(store, ['phone', 'storePhone', 'store_phone']);
    phone = phone.replaceAll(RegExp(r'\s'), '');
    if (phone.startsWith('+254')) {
      phone = phone.substring(4);
    } else if (phone.startsWith('254')) {
      phone = phone.substring(3);
    }
    _phoneLocal.text = phone.replaceAll(RegExp(r'\D'), '');
    _phone2Local.text = _normalizeLocalPhone(settingsPick(store, ['phone2', 'phone_2']));
    _phone3Local.text = _normalizeLocalPhone(settingsPick(store, ['phone3', 'phone_3']));
    _address1.text = settingsPick(store, [
      'line1',
      'addressLine1',
      'address_line_1',
      'address',
      'street',
    ]);
    _city.text = settingsPick(store, ['city']);
    _state.text = settingsPick(store, ['state', 'province', 'region']);
    _country.text = settingsPick(store, ['country']);
    _postal.text = settingsPick(store, ['postalCode', 'postal_code', 'zip', 'zipCode']);
    _supportEmail.text = settingsPick(store, ['contactEmail', 'contact_email', 'supportEmail']);
    _description.text = settingsPick(store, ['description', 'tagline']);

    final bt = settingsPick(data, ['businessType', 'business_type']);
    if (bt.isNotEmpty && _businessTypeOptions.contains(bt)) {
      _businessType = bt;
    } else if (bt.isNotEmpty) {
      _businessType = bt;
    }
    final sell = settingsPick(data, ['selling', 'sellingCategory', 'selling_category']);
    if (sell.isNotEmpty && _sellingOptions.contains(sell)) {
      _sellingCategory = sell;
    } else if (sell.isNotEmpty) {
      _sellingCategory = sell;
    }
    final countriesRaw = data['countries'];
    if (countriesRaw is List) {
      _countryOptions = countriesRaw
          .map((c) {
            if (c is Map) {
              return settingsPick(Map<String, dynamic>.from(c), ['name', 'label', 'code', 'country']);
            }
            return c?.toString() ?? '';
          })
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList();
    }
    final currency = settingsSection(data, 'currency') ?? {};
    _currencyCode.text = settingsPick(currency, ['code'], fallback: 'KES');
    _currencySymbol.text = settingsPick(currency, ['symbol'], fallback: 'KSh');
    _decimalPlaces.text = settingsPick(currency, ['decimalPlaces', 'decimal_places'], fallback: '0');
    _thousandSeparator.text = settingsPick(currency, ['thousandSeparator', 'thousand_separator'], fallback: ',');
    _decimalSeparator.text = settingsPick(currency, ['decimalSeparator', 'decimal_separator'], fallback: '.');
    _captureSaveBaseline();
  }

  String _normalizeLocalPhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'\s'), '');
    if (phone.startsWith('+254')) phone = phone.substring(4);
    if (phone.startsWith('254')) phone = phone.substring(3);
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  String _toE164(String local) {
    final digits = local.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    return digits.isEmpty ? '' : '+254$digits';
  }

  void _applyLogoFromSettings(Map<String, dynamic> data, {bool preserveLocalPending = true}) {
    final prevLogo = _logoImageUrl;
    final normalizedLogo = readStoreLogoFromSettings(data);
    if (normalizedLogo.isNotEmpty) {
      if (_logoImageUrl != normalizedLogo) {
        _logoImageUrl = normalizedLogo;
        _logoCacheEpoch++;
      }
      if (!_logoClearedByUser) {
        _logoPreviewLocalPath = null;
      }
    } else if (_logoClearedByUser) {
      _logoImageUrl = null;
      _logoPreviewLocalPath = null;
      _logoCacheEpoch++;
    } else if (prevLogo != null && prevLogo.isNotEmpty) {
      // GET settings often omits `static_options.store_logo` even after a successful PATCH.
      _logoImageUrl = prevLogo;
    }
    if (preserveLocalPending) return;
    _pendingLogoLocalPath = null;
  }

  void _hydrateFrom(Map<String, dynamic> data, {bool preserveLocalPending = true}) {
    _hydrateFormFieldsFrom(data);
    _applyLogoFromSettings(data, preserveLocalPending: preserveLocalPending);
    if (!preserveLocalPending) {
      _logoClearedByUser = false;
    }
  }

  bool get _hasLogoPreview {
    if (_logoClearedByUser) return false;
    if (_pendingLogoLocalPath != null && _pendingLogoLocalPath!.isNotEmpty) {
      return true;
    }
    if (_logoPreviewLocalPath != null &&
        _logoPreviewLocalPath!.isNotEmpty &&
        File(_logoPreviewLocalPath!).existsSync()) {
      return true;
    }
    return _logoImageUrl != null && _logoImageUrl!.isNotEmpty;
  }

  String? get _activeLogoLocalPath {
    if (_pendingLogoLocalPath != null && _pendingLogoLocalPath!.isNotEmpty) {
      return _pendingLogoLocalPath;
    }
    if (_logoPreviewLocalPath != null &&
        _logoPreviewLocalPath!.isNotEmpty &&
        File(_logoPreviewLocalPath!).existsSync()) {
      return _logoPreviewLocalPath;
    }
    return null;
  }

  String _currentFormSignature() {
    final phoneDigits =
        _phoneLocal.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    return jsonEncode({
      'name': _storeName.text.trim(),
      'domain': _domain.text.trim(),
      'phone': phoneDigits,
      'line1': _address1.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'country': _country.text.trim(),
      'postal': _postal.text.trim(),
      'supportEmail': _supportEmail.text.trim(),
      'description': _description.text.trim(),
      'businessType': _businessType,
      'selling': _sellingCategory,
      'logo': normalizeStoreMediaUrl(_logoImageUrl ?? ''),
      'pendingLogo': _pendingLogoLocalPath ?? '',
      'logoCleared': _logoClearedByUser,
    });
  }

  void _captureSaveBaseline() {
    _baselineFormSignature = _currentFormSignature();
  }

  bool _hasUnsavedChanges() =>
      _currentFormSignature() != _baselineFormSignature;

  /// Keeps the logo visible after save when the settings GET omits `store_logo`.
  void _ensureLogoUrlAfterSave({
    required String savedLogoUrl,
    required bool cleared,
    String? localPreviewPath,
  }) {
    if (cleared) {
      _logoImageUrl = null;
      _pendingLogoLocalPath = null;
      _logoPreviewLocalPath = null;
      _logoCacheEpoch++;
      return;
    }
    final normalized = normalizeStoreMediaUrl(savedLogoUrl);
    if (normalized.isEmpty) return;
    if (_logoImageUrl != normalized) {
      _logoImageUrl = normalized;
      _logoCacheEpoch++;
    }
    _pendingLogoLocalPath = null;
    final preview = localPreviewPath?.trim();
    if (preview != null &&
        preview.isNotEmpty &&
        File(preview).existsSync()) {
      _logoPreviewLocalPath = preview;
    }
  }

  String? _saveSuccessMessage({
    required ApiResponse<dynamic> response,
    required bool logoSaved,
    required bool logoCleared,
  }) {
    if (!response.success && _isBenignNoUpdateResponse(response)) {
      if (logoSaved) {
        return 'Your logo is already saved on your storefront.';
      }
      return 'Store settings are already saved.';
    }
    if (logoCleared) return 'Changes saved. Store logo removed.';
    if (logoSaved) {
      return 'Changes saved. Your logo is updated on your storefront.';
    }
    return null;
  }

  bool _messageIndicatesNoSettingsUpdate(String raw) {
    final msg = raw.toLowerCase();
    return msg.contains('no settings fields') ||
        msg.contains('nothing to update') ||
        msg.contains('no changes');
  }

  bool _isBenignNoUpdateResponse(ApiResponse<dynamic> response) {
    final candidates = <String>[
      response.error?.message ?? '',
      if (response.data is Map)
        (response.data as Map)['message']?.toString() ?? '',
    ];
    for (final raw in candidates) {
      if (_messageIndicatesNoSettingsUpdate(raw)) return true;
    }
    return false;
  }

  bool _isBenignNoUpdateDio(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final candidates = <String>[
        data['message']?.toString() ?? '',
        if (data['error'] is Map)
          (data['error'] as Map)['message']?.toString() ?? '',
      ];
      for (final raw in candidates) {
        if (_messageIndicatesNoSettingsUpdate(raw)) return true;
      }
    }
    return false;
  }

  void _showSavedSnack({String? message}) {
    if (!mounted) return;
    final fromTutorial =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              (fromTutorial
                  ? 'Changes saved. Returning to tutorial…'
                  : 'Changes saved'),
        ),
        duration: Duration(seconds: fromTutorial ? 3 : 2),
      ),
    );
  }

  Future<void> _afterSuccessfulSave({String? message}) async {
    _captureSaveBaseline();
    _logoClearedByUser = false;
    final normalizedSubdomain = _domain.text.trim();
    final rootHost = (Uri.tryParse(AppConfig.publicApiBaseUrl)?.host ?? 'dukanest.com')
        .replaceFirst(RegExp(r'^www\.'), '');
    await ref.read(tokenStorageProvider).saveStoreIdentity(
          name: _storeName.text.trim(),
          subdomain: normalizedSubdomain,
          storeUrl: normalizedSubdomain.isNotEmpty
              ? 'https://$normalizedSubdomain.$rootHost'
              : '',
          logoUrl: _logoImageUrl,
        );
    ref.invalidate(storeIdentityProvider);
    ref.invalidate(dashboardGettingStartedProvider);
    if (!mounted) return;
    _showSavedSnack(message: message);
    final fromTutorial =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    if (fromTutorial) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      context.go('/first-run-tutorial');
    }
  }

  Map<String, dynamic> _mergedStaticOptions(
    Map<String, dynamic>? root, {
    String? storeLogo,
    bool clearStoreLogo = false,
  }) {
    final merged = <String, dynamic>{};
    if (root != null) {
      final raw = root['static_options'] ?? root['staticOptions'];
      if (raw is Map) {
        merged.addAll(Map<String, dynamic>.from(raw));
      }
    }
    if (clearStoreLogo) {
      merged['store_logo'] = '';
    } else if (storeLogo != null && storeLogo.trim().isNotEmpty) {
      merged['store_logo'] = storeLogo.trim();
    }
    return merged;
  }

  /// Storefront logo: prefer `store.logo` (mobile PATCH); also merge `static_options.store_logo` + flat aliases.
  Map<String, dynamic> _logoSettingsPatch(
    String logo, {
    Map<String, dynamic>? settingsRoot,
  }) {
    final normalized = normalizeStoreMediaUrl(logo);
    final staticOptions = _mergedStaticOptions(
      settingsRoot,
      storeLogo: normalized,
    );
    return {
      'store': {'logo': normalized},
      'store_logo': normalized,
      'storeLogo': normalized,
      'logoUrl': normalized,
      'logo_url': normalized,
      'static_options': staticOptions,
      'staticOptions': Map<String, dynamic>.from(staticOptions),
    };
  }

  Map<String, dynamic> _logoClearSettingsPatch({Map<String, dynamic>? settingsRoot}) {
    final staticOptions = _mergedStaticOptions(
      settingsRoot,
      clearStoreLogo: true,
    );
    return {
      'store': {'logo': ''},
      'store_logo': '',
      'storeLogo': '',
      'logoUrl': '',
      'logo_url': '',
      'static_options': staticOptions,
      'staticOptions': Map<String, dynamic>.from(staticOptions),
    };
  }

  void _mergeLogoIntoSettingsBody(
    Map<String, dynamic> body, {
    required String logo,
    required bool clear,
    Map<String, dynamic>? settingsRoot,
  }) {
    final logoPatch = clear
        ? _logoClearSettingsPatch(settingsRoot: settingsRoot)
        : _logoSettingsPatch(logo, settingsRoot: settingsRoot);
    final existingStore = body['store'];
    final storeMap = existingStore is Map
        ? Map<String, dynamic>.from(existingStore)
        : <String, dynamic>{};
    final logoStore = logoPatch['store'];
    if (logoStore is Map) {
      storeMap.addAll(Map<String, dynamic>.from(logoStore));
    }
    body['store'] = storeMap;
    for (final entry in logoPatch.entries) {
      if (entry.key == 'store') continue;
      body[entry.key] = entry.value;
    }
  }

  String _formatApiError(Object e, {String fallback = 'Could not save store logo'}) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final details = data['details'];
        if (details is List && details.isNotEmpty) {
          final lines = <String>[];
          for (final item in details) {
            if (item is Map) {
              final msg = item['message'] ?? item['msg'];
              if (msg is String && msg.trim().isNotEmpty) {
                lines.add(msg.trim());
              }
            }
          }
          if (lines.isNotEmpty) return lines.join('\n');
        }
        final msg = data['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
        final err = data['error'];
        if (err is Map && err['message'] is String) {
          return (err['message'] as String).trim();
        }
      }
      if (e.message != null && e.message!.trim().isNotEmpty) {
        return e.message!.trim();
      }
    }
    return fallback;
  }

  static String _settingsHydrationSignature(Map<String, dynamic>? root) {
    if (root == null || root.isEmpty) return '';
    final store = settingsSection(root, 'store');
    final storeKeys = store == null ? <String>[] : (store.keys.toList()..sort());
    final storeJson =
        store == null ? <String, dynamic>{} : {for (final k in storeKeys) k: store[k]};
    return jsonEncode({
      'store': storeJson,
      'logo': readStoreLogoFromSettings(root),
      'businessType': settingsPick(root, ['businessType', 'business_type']),
      'selling': settingsPick(root, ['selling', 'sellingCategory', 'selling_category']),
    });
  }

  void _hydrateWhenSettingsChange(Map<String, dynamic>? root) {
    if (_skipNextSettingsHydrate) {
      _skipNextSettingsHydrate = false;
      return;
    }
    final sig = _settingsHydrationSignature(root);
    if (_lastHydratedSettingsSignature != null &&
        sig == _lastHydratedSettingsSignature) {
      return;
    }
    _lastHydratedSettingsSignature = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateFrom(root ?? {}, preserveLocalPending: true);
      setState(() {});
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_storeName.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'storeName',
        message: 'Store name is required.',
      );
      return;
    }
    if (_domain.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'domain',
        message: 'Store domain is required.',
      );
      return;
    }
    final supportEmail = _supportEmail.text.trim();
    if (supportEmail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(supportEmail)) {
      reportFieldError(
        fieldId: 'supportEmail',
        message: 'Enter a valid support email address.',
      );
      return;
    }
    clearAllFieldErrors();
    if (!_hasUnsavedChanges()) {
      _showSavedSnack(
        message: 'Store settings are already saved.',
      );
      return;
    }
    setState(() {
      _saving = true;
      if (_pendingLogoLocalPath != null && !_logoClearedByUser) {
        _uploadingLogo = true;
        _logoUploadProgress = null;
      }
    });
    try {
      final api = ref.read(apiClientProvider);
      final name = _storeName.text.trim();
      final line1 = _address1.text.trim();
      final phoneE164 = _toE164(_phoneLocal.text);
      final phone2E164 = _toE164(_phone2Local.text);
      final phone3E164 = _toE164(_phone3Local.text);
      final storePatch = <String, dynamic>{
        'name': name,
        'line1': line1,
        'address_line_1': line1,
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'country': _country.text.trim(),
        'postalCode': _postal.text.trim(),
        'postal_code': _postal.text.trim(),
        'contactEmail': _supportEmail.text.trim(),
        'contact_email': _supportEmail.text.trim(),
        'description': _description.text.trim(),
      };
      if (phoneE164.isNotEmpty) {
        storePatch['phone'] = phoneE164;
        storePatch['store_phone'] = phoneE164;
      }
      if (phone2E164.isNotEmpty) storePatch['phone2'] = phone2E164;
      if (phone3E164.isNotEmpty) storePatch['phone3'] = phone3E164;
      var logo = normalizeStoreMediaUrl(_logoImageUrl ?? '');
      String? uploadedFromLocalPath;
      if (_pendingLogoLocalPath != null && !_logoClearedByUser) {
        uploadedFromLocalPath = _pendingLogoLocalPath;
        final uploadedUrl = await _uploadLogoFile(_pendingLogoLocalPath!);
        if (!mounted) return;
        if (uploadedUrl == null) return;
        logo = uploadedUrl;
        _logoImageUrl = uploadedUrl;
        _logoCacheEpoch++;
      }
      final shouldPersistLogo = logo.isNotEmpty || _logoClearedByUser;

      Map<String, dynamic>? settingsRoot;
      try {
        settingsRoot = await ref.read(dashboardSettingsProvider.future);
      } catch (_) {
        settingsRoot = null;
      }

      final body = <String, dynamic>{
        'store': storePatch,
        'currency': {
          'code': _currencyCode.text.trim(),
          'symbol': _currencySymbol.text.trim(),
          'decimalPlaces': int.tryParse(_decimalPlaces.text.trim()) ?? 0,
          'thousandSeparator': _thousandSeparator.text.trim(),
          'decimalSeparator': _decimalSeparator.text.trim(),
        },
        'businessType': _businessType,
        'business_type': _businessType,
        'selling': _sellingCategory,
        'selling_category': _sellingCategory,
        'sellingCategory': _sellingCategory,
      };
      if (shouldPersistLogo) {
        _mergeLogoIntoSettingsBody(
          body,
          logo: logo,
          clear: _logoClearedByUser,
          settingsRoot: settingsRoot,
        );
      }

      late final ApiResponse<dynamic> r;
      try {
        r = await api.patchDashboardSettings(body);
      } on DioException catch (e) {
        if (!mounted) return;
        if (_isBenignNoUpdateDio(e) && shouldPersistLogo) {
          _ensureLogoUrlAfterSave(
            savedLogoUrl: logo,
            cleared: _logoClearedByUser,
            localPreviewPath: uploadedFromLocalPath,
          );
          _skipNextSettingsHydrate = true;
          _logoClearedByUser = false;
          await _afterSuccessfulSave(
            message: logo.isNotEmpty && !_logoClearedByUser
                ? 'Your logo is already saved on your storefront.'
                : 'Store settings are already saved.',
          );
          return;
        }
        if (_isBenignNoUpdateDio(e)) {
          await _afterSuccessfulSave(
            message: 'Store settings are already saved.',
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatApiError(e, fallback: 'Could not save'))),
        );
        return;
      }
      if (!mounted) return;
      if (!r.success && !_isBenignNoUpdateResponse(r)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Could not save')),
        );
        return;
      }
      final patched = unwrapSettingsData(r.data);
      if (patched != null) {
        _hydrateFormFieldsFrom(patched);
        _applyLogoFromSettings(patched, preserveLocalPending: true);
        _lastHydratedSettingsSignature = _settingsHydrationSignature(patched);
      }
      _ensureLogoUrlAfterSave(
        savedLogoUrl: logo,
        cleared: _logoClearedByUser,
        localPreviewPath: uploadedFromLocalPath,
      );
      _skipNextSettingsHydrate = true;
      final refreshedRoot = await ref.refresh(dashboardSettingsProvider.future);
      if (refreshedRoot != null) {
        _hydrateFormFieldsFrom(refreshedRoot);
        _applyLogoFromSettings(refreshedRoot, preserveLocalPending: true);
        _lastHydratedSettingsSignature = _settingsHydrationSignature(refreshedRoot);
        _ensureLogoUrlAfterSave(
          savedLogoUrl: logo,
          cleared: _logoClearedByUser,
          localPreviewPath: uploadedFromLocalPath,
        );
      }
      _logoClearedByUser = false;
      if (!mounted) return;
      final message = _saveSuccessMessage(
        response: r,
        logoSaved: logo.isNotEmpty && !_logoClearedByUser,
        logoCleared: _logoClearedByUser,
      );
      if (logo.isNotEmpty && !_logoClearedByUser) {
        ref.read(dashboardLocalStepCompletionsProvider.notifier).markComplete(
              DashboardOnboardingStepKeys.logo,
            );
      }
      await _afterSuccessfulSave(message: message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadingLogo = false;
          _logoUploadProgress = null;
        });
      }
    }
  }

  /// Uploads a local logo file; returns public URL or null on failure (shows snackbar).
  Future<String?> _uploadLogoFile(String filePath) async {
    final api = ref.read(apiClientProvider);
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.replaceAll(r'\', '/').split('/').last,
        ),
      });
      final r = await api.uploadMedia(
        form,
        onSendProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _logoUploadProgress = total > 0 ? sent / total : null;
          });
        },
      );
      if (!mounted) return null;
      if (!r.success || r.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Logo upload failed')),
        );
        return null;
      }
      final url = extractMediaUploadUrl(r.data);
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload succeeded but no image URL was returned.'),
          ),
        );
        return null;
      }
      return url;
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatApiError(e, fallback: 'Logo upload failed')),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _pickLogo() async {
    if (_uploadingLogo || _saving) return;
    final source = await _showLogoSourcePicker();
    if (!mounted || source == null) return;
    final file = await _picker.pickImage(source: source, maxWidth: 2048);
    if (!mounted || file == null) return;
    setState(() {
      _pendingLogoLocalPath = file.path;
      _logoClearedByUser = false;
      _logoCacheEpoch++;
    });
  }

  Future<ImageSource?> _showLogoSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _clearLogo() {
    if (_uploadingLogo || _saving) return;
    setState(() {
      _logoImageUrl = null;
      _pendingLogoLocalPath = null;
      _logoPreviewLocalPath = null;
      _logoCacheEpoch++;
      _logoClearedByUser = true;
    });
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This will sign you out, disable your store, and schedule hard deletion after the retention period.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final sub = (_serverSubdomain ?? _domain.text.trim()).trim();
    if (sub.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing store subdomain — reload settings and try again.')),
      );
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.postDeleteAccount({
        'confirmation': 'DELETE $sub',
      });
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Could not delete account')),
        );
        return;
      }
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: $e')),
        );
      }
    }
  }

  InputDecoration _fieldDeco(ThemeData theme, {String? hint, bool isInvalid = false}) {
    final errorColor = theme.colorScheme.error;
    final outlineColor = isInvalid
        ? errorColor
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.45);
    final width = isInvalid ? 1.5 : 1.0;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineColor, width: width),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineColor, width: width),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(dashboardSettingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(title: 'Store Settings'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'Store Settings'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardSettingsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        if (data != null) {
          _hydrateWhenSettingsChange(data);
        }
        return _buildMainScaffold(theme);
      },
    );
  }

  Widget _buildMainScaffold(ThemeData theme) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(
        title: 'Store Settings',
        showDivider: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _SectionCard(
            theme: theme,
            icon: Icons.storefront_outlined,
            title: 'Store Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Store Name'),
                KeyedSubtree(
                  key: keyFor('storeName'),
                  child: TextField(
                    controller: _storeName,
                    onChanged: (_) => clearFieldError('storeName'),
                    decoration: _fieldDeco(
                      theme,
                      isInvalid: isFieldInvalid('storeName'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label(theme, 'Store Domain'),
                KeyedSubtree(
                  key: keyFor('domain'),
                  child: TextField(
                    controller: _domain,
                    onChanged: (_) => clearFieldError('domain'),
                    decoration: _fieldDeco(
                      theme,
                      isInvalid: isFieldInvalid('domain'),
                    ).copyWith(
                      suffixText: '.dukanest.com',
                      suffixStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label(theme, 'Phone Number'),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
                        backgroundColor: theme.colorScheme.surfaceContainer,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🇰🇪', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('+254', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneLocal,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDeco(theme),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label(theme, 'Additional phones (optional)'),
                TextField(
                  controller: _phone2Local,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDeco(theme),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phone3Local,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDeco(theme),
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.payments_outlined,
            title: 'Currency',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Code'),
                          TextField(controller: _currencyCode, decoration: _fieldDeco(theme)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Symbol'),
                          TextField(controller: _currencySymbol, decoration: _fieldDeco(theme)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Decimal places'),
                          TextField(controller: _decimalPlaces, decoration: _fieldDeco(theme)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Thousands sep'),
                          TextField(controller: _thousandSeparator, decoration: _fieldDeco(theme)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Decimal sep'),
                          TextField(controller: _decimalSeparator, decoration: _fieldDeco(theme)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.branding_watermark_outlined,
            title: 'Store Logo',
            child: _buildLogoUploader(theme),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.category_outlined,
            title: 'Business Category',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Business Type'),
                _dropdown(
                  theme,
                  value: _businessTypeOptions.contains(_businessType) ? _businessType : _businessTypeOptions.first,
                  items: _businessTypeOptions,
                  onChanged: (v) => setState(() => _businessType = v ?? _businessTypeOptions.first),
                ),
                const SizedBox(height: 16),
                _label(theme, 'What are you selling?'),
                _dropdown(
                  theme,
                  value: _sellingOptions.contains(_sellingCategory)
                      ? _sellingCategory
                      : _sellingOptions.first,
                  items: _sellingOptions,
                  onChanged: (v) => setState(() => _sellingCategory = v ?? _sellingOptions.first),
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.description_outlined,
            title: 'Store Description',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _description,
                  minLines: 5,
                  maxLines: 8,
                  decoration: _fieldDeco(theme),
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.location_on_outlined,
            title: 'Physical Address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Address Line 1'),
                TextField(
                  controller: _address1,
                  decoration: _fieldDeco(theme),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'City'),
                          TextField(
                            controller: _city,
                            decoration: _fieldDeco(theme),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'State/Province'),
                          TextField(
                            controller: _state,
                            decoration: _fieldDeco(theme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Country'),
                          _countryOptions.isEmpty
                              ? TextField(
                                  controller: _country,
                                  decoration: _fieldDeco(theme),
                                )
                              : _dropdown(
                                  theme,
                                  value: _countryOptions.contains(_country.text.trim())
                                      ? _country.text.trim()
                                      : (_countryOptions.isNotEmpty ? _countryOptions.first : ''),
                                  items: _countryOptions,
                                  onChanged: (v) => setState(() => _country.text = v ?? ''),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Postal Code'),
                          TextField(
                            controller: _postal,
                            decoration: _fieldDeco(theme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.support_agent_outlined,
            title: 'Contact & Support',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Support Email'),
                KeyedSubtree(
                  key: keyFor('supportEmail'),
                  child: TextField(
                    controller: _supportEmail,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => clearFieldError('supportEmail'),
                    decoration: _fieldDeco(
                      theme,
                      isInvalid: isFieldInvalid('supportEmail'),
                    ).copyWith(
                      prefixIcon: Icon(Icons.mail_outline_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Used for order confirmations and customer inquiries.',
                  style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DeleteAccountSection(onDeletePressed: _confirmDeleteAccount),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        color: AppTheme.surface.withValues(alpha: 0.92),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoUploader(ThemeData theme) {
    final localPath = _activeLogoLocalPath;
    final hasLocalPreview = localPath != null;
    final progress = _logoUploadProgress;
    final progressPercent = progress != null ? (progress * 100).clamp(0, 100).toInt() : null;

    Widget centerVisual;
    if (_uploadingLogo) {
      centerVisual = SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            if (progressPercent != null)
              Text(
                '$progressPercent%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      );
    } else if (_hasLogoPreview) {
      final Widget imageChild;
      if (hasLocalPreview) {
        imageChild = Image.file(
          File(localPath),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined,
              color: theme.colorScheme.primary, size: 32),
        );
      } else {
        imageChild = CachedNetworkImage(
          imageUrl: _logoImageUrl!,
          cacheKey: 'store_logo_${_logoImageUrl}_$_logoCacheEpoch',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) {
            final fallback = _logoPreviewLocalPath;
            if (fallback != null &&
                fallback.isNotEmpty &&
                File(fallback).existsSync()) {
              return Image.file(
                File(fallback),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              );
            }
            return Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.store_rounded,
                  color: theme.colorScheme.primary, size: 32),
            );
          },
        );
      }
      centerVisual = Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(child: imageChild),
          if (_pendingLogoLocalPath != null && _pendingLogoLocalPath!.isNotEmpty)
            Positioned(
              bottom: -2,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unsaved',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: -4,
            right: -4,
            child: Material(
              color: theme.colorScheme.error,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: _clearLogo,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      centerVisual = Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(Icons.upload_file_rounded,
            color: theme.colorScheme.primary, size: 32),
      );
    }

    final String headline;
    final String hint;
    if (_uploadingLogo) {
      headline = progressPercent != null ? 'Uploading… $progressPercent%' : 'Uploading…';
      hint = 'Please keep this screen open until the upload completes.';
    } else if (_hasLogoPreview) {
      final hasUnsavedPick =
          _pendingLogoLocalPath != null && _pendingLogoLocalPath!.isNotEmpty;
      headline = hasUnsavedPick ? 'Logo ready to save' : 'Tap to replace logo';
      hint = hasUnsavedPick
          ? 'Confirm this image, then tap Save changes to publish it on your storefront.'
          : 'Shown on your storefront header. Tap X to remove.';
    } else {
      headline = 'Upload Store Logo';
      hint = 'Choose an image, then tap Save changes to apply it.';
    }

    return Material(
      color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: (_uploadingLogo || _saving) ? null : _pickLogo,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DashedRectPainter(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            radius: 16,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              children: [
                centerVisual,
                const SizedBox(height: 16),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_uploadingLogo) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _dropdown(
    ThemeData theme, {
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.unfold_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.child,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountSection extends StatelessWidget {
  const _DeleteAccountSection({required this.onDeletePressed});

  final VoidCallback onDeletePressed;

  static const _cardBg = Color(0xFFFFF5F5);
  static const _border = Color(0xFFFFCDD2);
  static const _titleRed = Color(0xFFB71C1C);
  static const _buttonRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: _titleRed, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _titleRed,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Permanently close your store. Your storefront and dashboard access will be disabled immediately. Store data is retained for up to 90 days before permanent deletion.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.45,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border.withValues(alpha: 0.9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: _titleRed, shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This action is serious',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _titleRed,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleting your account will sign you out, disable your store, and schedule hard deletion after the retention period. If you change your mind, contact support before the retention period expires.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onDeletePressed,
              style: FilledButton.styleFrom(
                backgroundColor: _buttonRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                'Delete my account',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), Radius.circular(radius));
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      var len = 0.0;
      while (len < metric.length) {
        final end = (len + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(len, end), paint);
        len += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
