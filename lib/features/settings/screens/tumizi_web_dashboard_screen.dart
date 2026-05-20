import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/dashboard_settings_provider.dart';

/// Cached for the session so Tumizi hub → withdrawal reuses the same snapshot (no duplicate fetch on navigate).
final _tumiziMerchantProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive();
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getTumiziMerchant();
    if (!response.success || response.data == null) {
      throw StateError(
        response.error?.message ?? 'Failed to load Tumizi merchant details',
      );
    }
    return _asMap(response.data);
  } on DioException catch (e) {
    throw StateError(_tumiziApiErrorMessage(e, 'merchant details'));
  }
});

final _tumiziWalletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive();
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getTumiziWallet();
    if (!response.success || response.data == null) {
      throw StateError(
          response.error?.message ?? 'Failed to load Tumizi wallet');
    }
    return _asMap(response.data);
  } on DioException catch (e) {
    throw StateError(_tumiziApiErrorMessage(e, 'wallet'));
  }
});

/// Cached store settings for withdrawal — avoids refetching on every visit.
final _withdrawalStoreSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  ref.keepAlive();
  final api = ref.watch(apiClientProvider);
  final response = await api.getDashboardSettings();
  if (!response.success || response.data == null) {
    throw StateError(response.error?.message ?? 'Failed to load store settings');
  }
  final unwrapped = unwrapSettingsData(response.data);
  if (unwrapped == null) {
    throw const FormatException('Invalid settings response');
  }
  return unwrapped;
});

final _tumiziRefundsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getTumiziRefunds();
    if (!response.success || response.data == null) {
      throw StateError(response.error?.message ?? 'Failed to load refunds');
    }
    final root = response.data;
    final list =
        root is Map ? (root['items'] ?? root['refunds'] ?? root['data']) : root;
    if (list is! List) return const <Map<String, dynamic>>[];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } on DioException catch (e) {
    throw StateError(_tumiziApiErrorMessage(e, 'refunds'));
  }
});

String _tumiziApiErrorMessage(Object error, String section) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 404) {
      return 'Could not find the mobile Tumizi $section endpoint. '
          'Confirm /api/v1/mobile/dashboard/tumizi routes are deployed.';
    }
    if (code == 401 || code == 403) {
      return 'Tumizi $section requires mobile dashboard access. Please sign in again or confirm your account has permission.';
    }
    return 'Could not load Tumizi $section${code == null ? '' : ' (HTTP $code)'}.';
  }
  return error.toString();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  final root = Map<String, dynamic>.from(value);
  final nested = root['data'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return root;
}

Map<String, dynamic> _section(Map<String, dynamic> root, List<String> keys) {
  for (final key in keys) {
    final value = root[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

/// Merge common Tumizi wallet JSON shapes (nested `wallet`, `walletAccount`, …)
/// so reads match the web/mobile proxy payload.
List<Map<String, dynamic>> _tumiziWalletSearchMaps(Map<String, dynamic> root) {
  final maps = <Map<String, dynamic>>[];
  for (final key in const [
    'wallet',
    'walletAccount',
    'wallet_account',
    'data',
    'walletDetails',
    'wallet_details',
  ]) {
    final value = root[key];
    if (value is Map<String, dynamic>) {
      maps.add(value);
    } else if (value is Map) {
      maps.add(Map<String, dynamic>.from(value));
    }
  }
  maps.add(root);
  return maps;
}

String _pick(Iterable<Map<String, dynamic>> sources, List<String> keys) {
  for (final source in sources) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      if (value is bool) return value ? 'active' : 'inactive';
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
  }
  return '-';
}

String _money(
  Iterable<Map<String, dynamic>> sources, {
  List<String> amountKeys = const [
    'availableBalance',
    'available_balance',
    'balance',
    'walletBalance',
    'wallet_balance',
  ],
  List<String> currencyKeys = const [
    'currency',
    'walletCurrency',
    'wallet_currency'
  ],
}) {
  final currency = _pick(sources, currencyKeys);
  final amount = _pick(sources, amountKeys);
  if (amount == '-') return currency == '-' ? '-' : '$currency 0';
  return '${currency == '-' ? 'KES' : currency} $amount';
}

/// Native Tumizi wallet hub. Section buttons open in-app pages.
class TumiziWebDashboardScreen extends ConsumerWidget {
  const TumiziWebDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wallet = ref.watch(_tumiziWalletProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Tumizi wallet'),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: _TumiziWithdrawalCta(
                onPressed: () => context.push('/tumizi-dashboard/withdrawals'),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Tumizi helps verify M-Pesa payments automatically, keep business money separate '
              'in your wallet, and withdraw wallet funds to M-Pesa when you need them.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _TumiziWalletSummaryCard(wallet: wallet),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'MANAGE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _TumiziManageCard(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF1D4ED8),
            iconBackground: const Color(0xFFE0F2FE),
            title: 'General information',
            subtitle: 'View your merchant account details',
            onTap: () => context.push('/tumizi-dashboard/general'),
          ),
          const SizedBox(height: 8),
          _TumiziManageCard(
            icon: Icons.edit_outlined,
            iconColor: const Color(0xFF3F6212),
            iconBackground: const Color(0xFFE9FCCD),
            title: 'Edit merchant',
            subtitle: 'Update your business information',
            onTap: () => context.push('/tumizi-dashboard/edit-merchant'),
          ),
          const SizedBox(height: 8),
          _TumiziManageCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF92400E),
            iconBackground: const Color(0xFFFFF7E6),
            title: 'Refunds',
            subtitle: 'Manage your refund policy',
            onTap: () => context.push('/tumizi-dashboard/refunds'),
          ),
        ],
      ),
    );
  }
}

class _TumiziManageCard extends StatelessWidget {
  const _TumiziManageCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TumiziWalletSummaryCard extends StatelessWidget {
  const _TumiziWalletSummaryCard({required this.wallet});

  final AsyncValue<Map<String, dynamic>> wallet;

  @override
  Widget build(BuildContext context) {
    return wallet.when(
      loading: () => const _TumiziWalletSummaryShell(
        balance: 'KES 0.00',
        status: 'Loading',
        loading: true,
      ),
      error: (error, stackTrace) => const _TumiziWalletSummaryShell(
        balance: 'KES 0.00',
        status: 'Unavailable',
      ),
      data: (root) {
        final balance = _walletBalanceFromRoot(root);
        final currency = _pick(
          _tumiziWalletSearchMaps(root),
          ['currency', 'walletCurrency', 'wallet_currency'],
        );
        final status = _pick(
          _tumiziWalletSearchMaps(root),
          ['accountStatus', 'account_status', 'status', 'enabled', 'active'],
        );

        return _TumiziWalletSummaryShell(
          balance:
              '${currency == '-' ? 'KES' : currency} ${balance.toStringAsFixed(2)}',
          status: status == '-' ? 'Active' : status,
        );
      },
    );
  }
}

class _TumiziWalletSummaryShell extends StatelessWidget {
  const _TumiziWalletSummaryShell({
    required this.balance,
    required this.status,
    this.loading = false,
  });

  final String balance;
  final String status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final active = normalized == 'active' || normalized == 'true';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  balance,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF22C55E) : Colors.white70,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  active ? 'Active' : status,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TumiziWithdrawalCta extends StatelessWidget {
  const _TumiziWithdrawalCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.phone_android_rounded, size: 19),
      label: Text(
        'M-Pesa withdrawal',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class TumiziGeneralInformationScreen extends ConsumerWidget {
  const TumiziGeneralInformationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_tumiziMerchantProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'General information'),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _TumiziErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(_tumiziMerchantProvider),
        ),
        data: (root) => _TumiziGeneralInformationBody(root: root),
      ),
    );
  }
}

class _TumiziGeneralInformationBody extends StatelessWidget {
  const _TumiziGeneralInformationBody({required this.root});

  final Map<String, dynamic> root;

  @override
  Widget build(BuildContext context) {
    final merchant = _section(root, ['merchant', 'merchantInformation']);
    final organisation = _section(root, [
      'organisation',
      'organization',
      'merchantOrganisation',
      'merchantOrganization',
    ]);
    final wallet = _section(root, ['wallet', 'walletAccount']);
    final profile = _section(root, ['merchantProfile', 'profile']);
    final owner = _section(root, ['owner', 'ownerProfile']);
    final sources = [root, merchant, organisation, wallet, profile, owner];
    final status =
        _pick([root, merchant], ['accountStatus', 'status', 'enabled']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _TumiziOverviewCard(
          status: status,
          items: [
            _TumiziInfoItem(
              'Organisation / Merchant Name',
              _pick(sources, [
                'organisationName',
                'organizationName',
                'merchantName',
                'name',
              ]),
            ),
            _TumiziInfoItem(
              'Primary contact',
              _pick(sources, [
                'primaryContact',
                'primary_contact',
                'merchantEmail',
                'merchant_email',
                'ownerEmail',
                'owner_email',
                'email',
              ]),
            ),
            _TumiziInfoItem('Account status', status),
            _TumiziInfoItem(
              'Merchant external ID',
              _pick([
                root,
                merchant
              ], [
                'merchantExternalId',
                'merchant_external_id',
                'externalId',
                'external_id',
              ]),
            ),
            _TumiziInfoItem('Region', _pick([root, merchant], ['region'])),
            _TumiziInfoItem('Available balance', _money([root, wallet])),
          ],
        ),
        const SizedBox(height: 14),
        _TumiziInfoSection(
          title: 'Merchant information',
          items: [
            _TumiziInfoItem(
              'Merchant ID',
              _pick([merchant, root], ['merchantId', 'merchant_id', 'id']),
            ),
            _TumiziInfoItem(
              'Merchant external ID',
              _pick([
                merchant,
                root
              ], [
                'merchantExternalId',
                'merchant_external_id',
                'externalId',
                'external_id',
              ]),
            ),
            _TumiziInfoItem(
                'Status', _pick([merchant, root], ['status', 'enabled'])),
          ],
        ),
        _TumiziInfoSection(
          title: 'Organisation',
          items: [
            _TumiziInfoItem(
              'Organisation ID',
              _pick([
                organisation,
                root
              ], [
                'organisationId',
                'organizationId',
                'organisation_id',
                'organization_id',
                'id',
              ]),
            ),
            _TumiziInfoItem(
              'Organisation name',
              _pick([
                organisation,
                root
              ], [
                'organisationName',
                'organizationName',
                'name',
              ]),
            ),
            _TumiziInfoItem(
              'Organisation domain',
              _pick([
                organisation,
                root
              ], [
                'organisationDomain',
                'organizationDomain',
                'domain',
                'subdomain',
              ]),
            ),
          ],
        ),
        _TumiziInfoSection(
          title: 'Wallet',
          items: [
            _TumiziInfoItem('Wallet ID',
                _pick([wallet, root], ['walletId', 'wallet_id', 'id'])),
            _TumiziInfoItem('Wallet name',
                _pick([wallet, root], ['walletName', 'wallet_name', 'name'])),
            _TumiziInfoItem(
              'Account number',
              _pick([
                wallet,
                root
              ], [
                'accountNumber',
                'account_number',
                'walletAccountNumber',
                'wallet_account_number',
              ]),
            ),
            _TumiziInfoItem(
                'Currency',
                _pick([wallet, root],
                    ['currency', 'walletCurrency', 'wallet_currency'])),
            _TumiziInfoItem('Available balance', _money([wallet, root])),
          ],
        ),
        _TumiziInfoSection(
          title: 'Merchant profile',
          items: [
            _TumiziInfoItem(
                'Merchant name',
                _pick([profile, merchant, root],
                    ['merchantName', 'merchant_name', 'name'])),
            _TumiziInfoItem(
                'Merchant email',
                _pick([profile, merchant, root],
                    ['merchantEmail', 'merchant_email', 'email'])),
            _TumiziInfoItem(
                'Merchant phone',
                _pick([profile, merchant, root],
                    ['merchantPhone', 'merchant_phone', 'phone'])),
            _TumiziInfoItem(
                'Country', _pick([profile, merchant, root], ['country'])),
            _TumiziInfoItem('Description',
                _pick([profile, merchant, root], ['description'])),
          ],
        ),
        _TumiziInfoSection(
          title: 'Owner',
          items: [
            _TumiziInfoItem('Owner name',
                _pick([owner, root], ['ownerName', 'owner_name', 'name'])),
            _TumiziInfoItem('Owner email',
                _pick([owner, root], ['ownerEmail', 'owner_email', 'email'])),
          ],
        ),
      ],
    );
  }
}

class TumiziEditMerchantScreen extends ConsumerStatefulWidget {
  const TumiziEditMerchantScreen({super.key});

  @override
  ConsumerState<TumiziEditMerchantScreen> createState() =>
      _TumiziEditMerchantScreenState();
}

class _TumiziEditMerchantScreenState
    extends ConsumerState<TumiziEditMerchantScreen> {
  final _merchantName = TextEditingController();
  final _merchantEmail = TextEditingController();
  final _merchantPhone = TextEditingController();
  final _country = TextEditingController(text: 'Kenya');
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _walletName = TextEditingController();
  final _walletAccountNumber = TextEditingController();
  final _walletCurrency = TextEditingController(text: 'KES');
  final _description = TextEditingController();

  String _merchantStatus = 'active';
  String _lastHydratedSignature = '';
  bool _saving = false;

  @override
  void dispose() {
    _merchantName.dispose();
    _merchantEmail.dispose();
    _merchantPhone.dispose();
    _country.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _walletName.dispose();
    _walletAccountNumber.dispose();
    _walletCurrency.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> root) {
    final signature = root.toString();
    if (signature == _lastHydratedSignature) return;
    _lastHydratedSignature = signature;

    final merchant = _section(root, ['merchant', 'merchantInformation']);
    final profile = _section(root, ['merchantProfile', 'profile']);
    final owner = _section(root, ['owner', 'ownerProfile']);
    final wallet = _section(root, ['wallet', 'walletAccount']);

    _merchantName.text = _pick(
        [profile, merchant, root], ['merchantName', 'merchant_name', 'name']);
    _merchantEmail.text = _pick([profile, merchant, root],
        ['merchantEmail', 'merchant_email', 'email']);
    _merchantPhone.text = _pick([profile, merchant, root],
        ['merchantPhone', 'merchant_phone', 'phone']).replaceAll('-', '');
    _country.text = _pick([profile, merchant, root], ['country']);
    if (_country.text == '-') _country.text = 'Kenya';
    _ownerName.text = _pick([owner, root], ['ownerName', 'owner_name', 'name']);
    _ownerEmail.text =
        _pick([owner, root], ['ownerEmail', 'owner_email', 'email']);
    _walletName.text =
        _pick([wallet, root], ['walletName', 'wallet_name', 'name']);
    _walletAccountNumber.text = _pick([
      wallet,
      root
    ], [
      'accountNumber',
      'account_number',
      'walletAccountNumber',
      'wallet_account_number',
    ]);
    _walletCurrency.text = _pick(
        [wallet, root], ['currency', 'walletCurrency', 'wallet_currency']);
    if (_walletCurrency.text == '-') _walletCurrency.text = 'KES';
    _merchantStatus =
        _pick([merchant, root], ['status', 'enabled']).toLowerCase();
    if (_merchantStatus != 'inactive') _merchantStatus = 'active';
    _description.text = _pick([profile, merchant, root], ['description']);
    if (_description.text == '-') _description.clear();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final body = {
        'merchantName': _merchantName.text.trim(),
        'merchantEmail': _merchantEmail.text.trim(),
        'merchantPhone': _merchantPhone.text.trim(),
        'country': _country.text.trim(),
        'description': _description.text.trim(),
        'status': _merchantStatus,
        'ownerName': _ownerName.text.trim(),
        'ownerEmail': _ownerEmail.text.trim(),
        'walletName': _walletName.text.trim(),
        'walletAccountNumber': _walletAccountNumber.text.trim(),
        'walletCurrency': _walletCurrency.text.trim(),
        'merchantProfile': {
          'merchantName': _merchantName.text.trim(),
          'merchantEmail': _merchantEmail.text.trim(),
          'merchantPhone': _merchantPhone.text.trim(),
          'country': _country.text.trim(),
          'description': _description.text.trim(),
        },
        'owner': {
          'ownerName': _ownerName.text.trim(),
          'ownerEmail': _ownerEmail.text.trim(),
        },
        'wallet': {
          'walletName': _walletName.text.trim(),
          'accountNumber': _walletAccountNumber.text.trim(),
          'currency': _walletCurrency.text.trim(),
          'status': _merchantStatus,
        },
      };
      final response =
          await ref.read(apiClientProvider).patchTumiziMerchant(body);
      if (!mounted) return;
      if (!response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(response.error?.message ??
                  'Could not save merchant changes')),
        );
        return;
      }
      ref.invalidate(_tumiziMerchantProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merchant changes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_tumiziMerchantProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Edit Merchant'),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _TumiziErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(_tumiziMerchantProvider),
        ),
        data: (root) {
          _hydrate(root);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Text(
                      'Update profile and financial configuration.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TumiziFormSection(
                      title: 'Merchant information',
                      subtitle:
                          'Core identification details for the merchant entity.',
                      children: [
                        _TumiziTextField(
                            label: 'Merchant name', controller: _merchantName),
                        _TumiziTextField(
                            label: 'Email address',
                            controller: _merchantEmail,
                            keyboardType: TextInputType.emailAddress),
                        _TumiziTextField(
                            label: 'Phone number',
                            controller: _merchantPhone,
                            keyboardType: TextInputType.phone),
                        _TumiziDropdownField(
                          label: 'Country',
                          value: _country.text,
                          values: const ['Kenya'],
                          onChanged: (v) =>
                              setState(() => _country.text = v ?? 'Kenya'),
                        ),
                      ],
                    ),
                    _TumiziFormSection(
                      title: 'Ownership',
                      subtitle:
                          'Stakeholder contact details and accountability.',
                      children: [
                        _TumiziTextField(
                            label: 'Owner name', controller: _ownerName),
                        _TumiziTextField(
                            label: 'Owner email',
                            controller: _ownerEmail,
                            keyboardType: TextInputType.emailAddress),
                      ],
                    ),
                    _TumiziFormSection(
                      title: 'Wallet details',
                      subtitle: 'Financial routing and transactional status.',
                      footer:
                          'Default settlement currency cannot be changed while the wallet is active.',
                      children: [
                        _TumiziTextField(
                            label: 'Wallet name', controller: _walletName),
                        _TumiziTextField(
                            label: 'Wallet account number',
                            controller: _walletAccountNumber),
                        _TumiziTextField(
                            label: 'Wallet currency',
                            controller: _walletCurrency,
                            enabled: false),
                        _TumiziDropdownField(
                          label: 'Merchant status',
                          value: _merchantStatus,
                          values: const ['active', 'inactive'],
                          onChanged: (v) =>
                              setState(() => _merchantStatus = v ?? 'active'),
                        ),
                      ],
                    ),
                    _TumiziDescriptionSection(controller: _description),
                  ],
                ),
              ),
              _TumiziEditActions(
                saving: _saving,
                onDiscard: () {
                  _lastHydratedSignature = '';
                  _hydrate(root);
                  setState(() {});
                },
                onSave: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class TumiziRefundsScreen extends ConsumerWidget {
  const TumiziRefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final refunds = ref.watch(_tumiziRefundsProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Refunds'),
      body: refunds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _TumiziErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(_tumiziRefundsProvider),
        ),
        data: (items) {
          final totalRefunded = _refundTotal(items);
          final pendingCount = _pendingRefundCount(items);
          final averageTime = _averageRefundTime(items);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refund records',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Detailed overview of customer refund requests, transaction references, and settlement statuses.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.4,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showTumiziMessage(
                          context,
                          'Refund filters will be available soon.',
                        ),
                        icon: const Icon(Icons.filter_alt_outlined, size: 16),
                        label: const Text('Filter'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(96, 40),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: items.isEmpty
                            ? null
                            : () => _showTumiziMessage(
                                  context,
                                  'Refund export will be available soon.',
                                ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export CSV'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 40),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const _RefundEmptyCard()
              else
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RefundRecordCard(item: item),
                    )),
              const SizedBox(height: 16),
              _RefundMetricsGrid(
                cards: [
                  _RefundMetricData(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total refunded',
                    value: _formatKes(totalRefunded),
                  ),
                  _RefundMetricData(
                    icon: Icons.hourglass_empty_rounded,
                    label: 'Pending processing',
                    value: pendingCount.toString(),
                  ),
                  _RefundMetricData(
                    icon: Icons.calendar_month_outlined,
                    label: 'Average time',
                    value: averageTime,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

void _showTumiziMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showTumiziErrorSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  final theme = Theme.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: theme.colorScheme.error,
    ),
  );
}

double _refundTotal(List<Map<String, dynamic>> items) {
  return items.fold<double>(0, (total, item) => total + _refundAmount(item));
}

double _refundAmount(Map<String, dynamic> item) {
  for (final key in const [
    'amount',
    'refundAmount',
    'refund_amount',
    'totalRefunded',
    'total_refunded',
  ]) {
    final value = item[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

int _pendingRefundCount(List<Map<String, dynamic>> items) {
  return items.where((item) {
    final status = _pick([item], ['status', 'state']).toLowerCase();
    return status.contains('pending') || status.contains('processing');
  }).length;
}

String _averageRefundTime(List<Map<String, dynamic>> items) {
  final durations = <Duration>[];
  for (final item in items) {
    final direct = _pick([
      item
    ], [
      'averageTime',
      'average_time',
      'processingTime',
      'processing_time',
      'duration',
    ]);
    if (direct != '-') return direct;
    final started =
        DateTime.tryParse(_pick([item], ['createdAt', 'created_at', 'date']));
    final ended = DateTime.tryParse(_pick([
      item
    ], [
      'processedAt',
      'processed_at',
      'completedAt',
      'completed_at',
      'updatedAt',
      'updated_at',
    ]));
    if (started != null && ended != null && ended.isAfter(started)) {
      durations.add(ended.difference(started));
    }
  }
  if (durations.isEmpty) return 'N/A';
  final avgMs = durations
          .map((duration) => duration.inMilliseconds)
          .reduce((a, b) => a + b) ~/
      durations.length;
  final avg = Duration(milliseconds: avgMs);
  if (avg.inDays > 0) return '${avg.inDays}d';
  if (avg.inHours > 0) return '${avg.inHours}h';
  if (avg.inMinutes > 0) return '${avg.inMinutes}m';
  return '${avg.inSeconds}s';
}

String _formatKes(double amount) {
  return 'KES ${amount.toStringAsFixed(2)}';
}

class _RefundEmptyCard extends StatelessWidget {
  const _RefundEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.folder_open_outlined,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No refund records found',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'It looks like there haven’t been any refunds processed yet. Once a refund is initiated through checkout or merchant tools, it will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => _showTumiziMessage(
              context,
              'Refund help content will be available soon.',
            ),
            child: const Text('Learn about refunds'),
          ),
        ],
      ),
    );
  }
}

class _RefundRecordCard extends StatelessWidget {
  const _RefundRecordCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return _TumiziInfoSection(
      title:
          _pick([item], ['reference', 'id', 'transactionId', 'transaction_id']),
      items: [
        _TumiziInfoItem('Status', _pick([item], ['status', 'state'])),
        _TumiziInfoItem('Amount', _money([item])),
        _TumiziInfoItem('Reason', _pick([item], ['reason', 'description'])),
        _TumiziInfoItem(
            'Created', _pick([item], ['createdAt', 'created_at', 'date'])),
      ],
    );
  }
}

class _RefundMetricsGrid extends StatelessWidget {
  const _RefundMetricsGrid({required this.cards});

  final List<_RefundMetricData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 420
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _RefundMetricCard(data: card)),
          ],
        );
      },
    );
  }
}

class _RefundMetricCard extends StatelessWidget {
  const _RefundMetricCard({required this.data});

  final _RefundMetricData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(data.icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundMetricData {
  const _RefundMetricData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _TumiziFormSection extends StatelessWidget {
  const _TumiziFormSection({
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _TumiziFormGrid(children: children),
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(
              footer!,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.35,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TumiziFormGrid extends StatelessWidget {
  const _TumiziFormGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _TumiziTextField extends StatelessWidget {
  const _TumiziTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.enabled = true,
    this.onChanged,
    this.hintText,
    this.hasError = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TumiziFieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          decoration: _tumiziInputDecoration(theme, hasError: hasError).copyWith(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _TumiziDropdownField extends StatelessWidget {
  const _TumiziDropdownField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValue = values.contains(value) ? value : values.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TumiziFieldLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          isExpanded: true,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          decoration: _tumiziInputDecoration(theme),
          items: values
              .map((v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(v == 'active' ? 'active' : v),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TumiziFieldLabel extends StatelessWidget {
  const _TumiziFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

InputDecoration _tumiziInputDecoration(ThemeData theme, {bool hasError = false}) {
  final borderColor =
      hasError ? theme.colorScheme.error : theme.colorScheme.outlineVariant;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: borderColor.withValues(alpha: hasError ? 1 : 0.35),
    ),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHigh,
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    errorBorder: border,
    focusedErrorBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: hasError ? theme.colorScheme.error : theme.colorScheme.primary,
        width: 1.4,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
  );
}

class _TumiziDescriptionSection extends StatefulWidget {
  const _TumiziDescriptionSection({required this.controller});

  final TextEditingController controller;

  @override
  State<_TumiziDescriptionSection> createState() =>
      _TumiziDescriptionSectionState();
}

class _TumiziDescriptionSectionState extends State<_TumiziDescriptionSection> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _TumiziDescriptionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.controller.text.characters.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merchant description',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Public-facing profile summary used for directory and receipts.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            maxLines: 5,
            maxLength: 255,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: _tumiziInputDecoration(theme).copyWith(counterText: ''),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Character count: $count/255',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TumiziEditActions extends StatelessWidget {
  const _TumiziEditActions({
    required this.saving,
    required this.onDiscard,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.96),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onDiscard,
                  child: const Text('Discard changes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TumiziMpesaWithdrawalScreen extends ConsumerStatefulWidget {
  const TumiziMpesaWithdrawalScreen({super.key});

  @override
  ConsumerState<TumiziMpesaWithdrawalScreen> createState() =>
      _TumiziMpesaWithdrawalScreenState();
}

class _TumiziMpesaWithdrawalScreenState
    extends ConsumerState<TumiziMpesaWithdrawalScreen> {
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  bool _submitting = false;
  bool _amountExceedsMax = false;

  @override
  void dispose() {
    _amount.dispose();
    _narration.dispose();
    super.dispose();
  }

  double get _amountValue {
    return double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
  }

  double get _estimatedFee => _withdrawalFee(_amountValue);

  Future<void> _submitWithdrawal(
    double balance,
    double maxGrossWithdrawal,
    String storePhone,
  ) async {
    if (_submitting) return;
    final amount = _amountValue;
    final phone = _normalizeKenyaMsisdn(storePhone);
    if (phone.isEmpty) {
      _showTumiziMessage(
        context,
        'Add your store phone number in Settings before withdrawing.',
      );
      return;
    }
    if (amount <= 0) {
      _showTumiziMessage(context, 'Enter a withdrawal amount.');
      return;
    }
    if (amount < _tumiziMinimumWithdrawalKes) {
      setState(() => _amountExceedsMax = false);
      _showTumiziErrorSnack(context,
          'Minimum withdrawal is ${_formatKes(_tumiziMinimumWithdrawalKes)}.');
      return;
    }
    if (amount > maxGrossWithdrawal ||
        amount + _withdrawalFee(amount) > balance + 0.009) {
      setState(() => _amountExceedsMax = true);
      _showTumiziErrorSnack(context,
          'Withdrawal cannot exceed ${_formatKes(maxGrossWithdrawal)} (maximum for your current balance).');
      return;
    }
    setState(() => _amountExceedsMax = false);
    setState(() => _submitting = true);
    try {
      final response =
          await ref.read(apiClientProvider).postTumiziWalletWithdrawal(
        {
          'amount': amount,
          'phoneNumber': phone,
          if (_narration.text.trim().isNotEmpty)
            'narration': _narration.text.trim(),
        },
      );
      if (!mounted) return;
      if (!response.success) {
        _showTumiziMessage(
          context,
          response.error?.message ?? 'Could not initiate withdrawal.',
        );
        return;
      }
      _amount.clear();
      _narration.clear();
      if (mounted) setState(() => _amountExceedsMax = false);
      ref.invalidate(_tumiziWalletProvider);
      _showTumiziMessage(context, 'Withdrawal request submitted.');
    } catch (e) {
      if (!mounted) return;
      _showTumiziMessage(context, 'Withdrawal failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = ref.watch(_tumiziWalletProvider);
    final merchant = ref.watch(_tumiziMerchantProvider);
    final storeSettings = ref.watch(_withdrawalStoreSettingsProvider);
    final walletRoot = wallet.valueOrNull;
    final merchantRoot = merchant.valueOrNull;
    final settingsRoot = storeSettings.valueOrNull;

    if (wallet.isLoading && walletRoot == null) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'M-Pesa withdrawal'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (wallet.hasError && walletRoot == null) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'M-Pesa withdrawal'),
        body: _TumiziErrorState(
          message: '${wallet.error}',
          onRetry: () {
            ref.invalidate(_tumiziWalletProvider);
            ref.invalidate(_tumiziMerchantProvider);
          },
        ),
      );
    }

    final root = walletRoot ?? <String, dynamic>{};
    final maps = _tumiziWalletSearchMaps(root);
    final data = _section(root, ['wallet', 'data', 'walletAccount']);
    final source = data.isEmpty ? root : data;
    final balance = _walletBalanceFromRoot(root);
    final currency = _pick(
      maps,
      ['currency', 'walletCurrency', 'wallet_currency'],
    );
    final activity = _walletActivity(root, source);
    final maxGross = _resolveMaxGrossWithdrawal(root, balance);
    final feeAtMax = _withdrawalFee(maxGross);
    final accountNumber = _tumiziWalletAccountDisplay(root, merchantRoot);
    final walletStatus = _tumiziWalletStatusLabel(root);
    final storePhone = _storePhoneFromSettings(settingsRoot);
    final amountVal = _amountValue;
    final amountOutOfRange = amountVal > 0 &&
        (amountVal > maxGross ||
            amountVal + _withdrawalFee(amountVal) > balance + 0.009);
    final showAmountWarning =
        amountOutOfRange && amountVal >= _tumiziMinimumWithdrawalKes;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'M-Pesa withdrawal'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (wallet.isLoading || merchant.isLoading || storeSettings.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Updating wallet details…',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (storeSettings.hasError && storePhone.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Store phone could not be loaded. Update it in Settings to enable withdrawals.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          _WithdrawalWalletCard(
            accountNumber: accountNumber,
            walletStatus: walletStatus,
            balance: balance,
            currency: currency == '-' ? 'KES' : currency,
            maxWithdrawable: maxGross,
            estimatedFeeAtMax: feeAtMax,
            onRefresh: () {
              ref.invalidate(_tumiziWalletProvider);
              ref.invalidate(_tumiziMerchantProvider);
            },
          ),
          const SizedBox(height: 12),
          _InitiateWithdrawalCard(
            amount: _amount,
            narration: _narration,
            estimatedFee: _estimatedFee,
            maxWithdrawable: maxGross,
            saving: _submitting,
            amountFieldInvalid: _amountExceedsMax || showAmountWarning,
            storePhone: storePhone,
            onAmountChanged: () {
              final amt = _amountValue;
              setState(() {
                _amountExceedsMax = amt > 0 &&
                    (amt > maxGross ||
                        amt + _withdrawalFee(amt) > balance + 0.009);
              });
            },
            onSubmit: () => _submitWithdrawal(balance, maxGross, storePhone),
          ),
          const SizedBox(height: 12),
          _RecentWithdrawalActivity(activity: activity),
          const SizedBox(height: 12),
          const _WithdrawalChargeTiersCard(),
          const SizedBox(height: 12),
          const _WithdrawalNoteCard(
            icon: Icons.info_outline_rounded,
            title: 'Important note',
            message:
                'Withdrawals are sent only to your store phone number for security. '
                'Payouts are usually credited within a few minutes.',
          ),
          const SizedBox(height: 12),
          const _WithdrawalNoteCard(
            icon: Icons.verified_user_outlined,
            title: 'Encrypted transfers',
            message:
                'Withdrawal requests are sent over TLS. High-value activity may require additional verification from Tumizi or your bank partner.',
          ),
        ],
      ),
    );
  }
}

const double _tumiziMinimumWithdrawalKes = 101;

double _walletBalanceFromRoot(Map<String, dynamic> root) {
  for (final map in _tumiziWalletSearchMaps(root)) {
    for (final key in const [
      'availableBalance',
      'available_balance',
      'balance',
      'walletBalance',
      'wallet_balance',
    ]) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed =
            double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed != null) return parsed;
      }
    }
  }
  return 0;
}

double? _maxWithdrawableFromApi(Map<String, dynamic> root) {
  for (final map in _tumiziWalletSearchMaps(root)) {
    for (final key in const [
      'maxWithdrawable',
      'max_withdrawable',
      'maxWithdrawAmount',
      'max_withdraw_amount',
      'withdrawableBalance',
      'withdrawable_balance',
      'availableForWithdrawal',
      'available_for_withdrawal',
    ]) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed =
            double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed != null) return parsed;
      }
    }
  }
  return null;
}

double _maxTumiziGrossWithdrawalFromBalance(double balance) {
  if (balance <= 0) return 0;
  if (_withdrawalFee(_tumiziMinimumWithdrawalKes) +
          _tumiziMinimumWithdrawalKes >
      balance + 1e-9) {
    return 0;
  }
  var low = _tumiziMinimumWithdrawalKes;
  var high = balance;
  var best = 0.0;
  for (var i = 0; i < 80; i++) {
    final mid = (low + high) / 2;
    final total = mid + _withdrawalFee(mid);
    if (total <= balance + 1e-9) {
      best = mid;
      low = mid;
    } else {
      high = mid;
    }
  }
  return best;
}

double _resolveMaxGrossWithdrawal(
  Map<String, dynamic> root,
  double balance,
) {
  final fromApi = _maxWithdrawableFromApi(root);
  if (fromApi != null && fromApi >= 0) {
    final cap = _maxTumiziGrossWithdrawalFromBalance(balance);
    return math.min(fromApi, cap);
  }
  return _maxTumiziGrossWithdrawalFromBalance(balance);
}

List<Map<String, dynamic>> _tumiziMerchantSearchMaps(Map<String, dynamic>? root) {
  if (root == null || root.isEmpty) return const [];
  final maps = <Map<String, dynamic>>[];
  for (final key in const [
    'wallet',
    'walletAccount',
    'wallet_account',
    'merchant',
    'merchantInformation',
    'merchantProfile',
    'profile',
    'owner',
    'ownerProfile',
    'config',
    'tumiziConfig',
    'settings',
  ]) {
    final value = root[key];
    if (value is Map) {
      maps.add(Map<String, dynamic>.from(value));
    }
  }
  maps.add(root);
  return maps;
}

String _storePhoneFromSettings(Map<String, dynamic>? settingsRoot) {
  if (settingsRoot == null || settingsRoot.isEmpty) return '';
  final store = settingsSection(settingsRoot, 'store') ?? {};
  final raw = settingsPick(store, ['phone', 'storePhone', 'store_phone']);
  if (raw.isEmpty) return '';
  return _normalizeKenyaMsisdn(raw);
}

String _normalizeKenyaMsisdn(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('0') && digits.length >= 10) {
    digits = '254${digits.substring(1)}';
  } else if (digits.length == 9 && digits.startsWith('7')) {
    digits = '254$digits';
  }
  return digits;
}

String _formatMaskedKenyaPhone(String msisdn) {
  final d = _normalizeKenyaMsisdn(msisdn);
  if (d.length < 12) return msisdn.isEmpty ? '—' : msisdn;
  final local = d.substring(3);
  if (local.length < 9) return '+$d';
  final start = local.substring(0, 3);
  final end = local.substring(7);
  return '+254 $start **** $end';
}

String _tumiziWalletAccountDisplay(
  Map<String, dynamic> walletRoot,
  Map<String, dynamic>? merchantRoot,
) {
  const keys = [
    'walletAccountNumber',
    'wallet_account_number',
    'accountNumber',
    'account_number',
    'walletId',
    'wallet_id',
    'tillNumber',
    'till_number',
    'paybillNumber',
    'paybill_number',
    'merchantWalletId',
    'merchant_wallet_id',
  ];

  final w = _pick(_tumiziWalletSearchMaps(walletRoot), keys);
  if (w != '-') return w;

  if (merchantRoot != null && merchantRoot.isNotEmpty) {
    final m = _pick(_tumiziMerchantSearchMaps(merchantRoot), keys);
    if (m != '-') return m;

    final externalId = _pick(
      _tumiziMerchantSearchMaps(merchantRoot),
      [
        'merchantExternalId',
        'merchant_external_id',
        'externalId',
        'external_id',
      ],
    );
    if (externalId != '-') return externalId;
  }
  return '-';
}

String _tumiziWalletStatusLabel(Map<String, dynamic> walletRoot) {
  final status = _pick(
    _tumiziWalletSearchMaps(walletRoot),
    ['accountStatus', 'account_status', 'status', 'enabled', 'active'],
  );
  if (status == '-') return 'Active';
  final normalized = status.toLowerCase();
  if (normalized == 'true') return 'Active';
  if (normalized == 'false') return 'Inactive';
  return status;
}

double _withdrawalFee(double amount) {
  if (amount <= 0) return 0;
  if (amount <= 100) return 0;
  if (amount <= 500) return 6;
  if (amount <= 1000) return 12;
  if (amount <= 1500) return 20;
  if (amount <= 2500) return 30;
  if (amount <= 5000) return 40;
  if (amount <= 10000) return 55;
  if (amount <= 35000) return 60;
  return 68;
}

List<Map<String, dynamic>> _walletActivity(
  Map<String, dynamic> root,
  Map<String, dynamic> source,
) {
  final raw = root['activity'] ??
      root['transactions'] ??
      root['withdrawals'] ??
      source['activity'] ??
      source['transactions'] ??
      source['withdrawals'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class _WithdrawalWalletCard extends StatelessWidget {
  const _WithdrawalWalletCard({
    required this.accountNumber,
    required this.walletStatus,
    required this.balance,
    required this.currency,
    required this.maxWithdrawable,
    required this.estimatedFeeAtMax,
    required this.onRefresh,
  });

  final String accountNumber;
  final String walletStatus;
  final double balance;
  final String currency;
  final double maxWithdrawable;
  final double estimatedFeeAtMax;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WithdrawalLabel('Wallet account number'),
                    const SizedBox(height: 6),
                    Text(
                      accountNumber == '-' ? '—' : accountNumber,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  walletStatus,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WithdrawalLabel('Available balance'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatKes(balance),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: onRefresh,
                tooltip: 'Refresh balance',
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WithdrawalLabel('Currency'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(currency),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          currency == 'KES' ? 'Kenya Shillings' : currency,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WithdrawalLabel('Max withdrawable'),
                    const SizedBox(height: 6),
                    Text(
                      _formatKes(maxWithdrawable),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Est. fee at max: ${_formatKes(estimatedFeeAtMax)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InitiateWithdrawalCard extends StatelessWidget {
  const _InitiateWithdrawalCard({
    required this.amount,
    required this.narration,
    required this.estimatedFee,
    required this.maxWithdrawable,
    required this.saving,
    required this.amountFieldInvalid,
    required this.storePhone,
    required this.onAmountChanged,
    required this.onSubmit,
  });

  final TextEditingController amount;
  final TextEditingController narration;
  final double estimatedFee;
  final double maxWithdrawable;
  final bool saving;
  final bool amountFieldInvalid;
  final String storePhone;
  final VoidCallback onAmountChanged;
  final VoidCallback onSubmit;

  bool get _canWithdraw => storePhone.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TumiziTextField(
            label: 'Withdrawal amount',
            controller: amount,
            keyboardType: TextInputType.number,
            hasError: amountFieldInvalid,
            onChanged: (_) => onAmountChanged(),
            hintText: 'KES 0.00',
          ),
          const SizedBox(height: 8),
          if (_canWithdraw)
            Text(
              'Withdraw to: ${_formatMaskedKenyaPhone(storePhone)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text(
              'Add your store phone number in Settings before withdrawing.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Minimum withdrawal: ${_formatKes(_tumiziMinimumWithdrawalKes)} · '
            'Max: ${_formatKes(maxWithdrawable)} · Fee for this amount: ${_formatKes(estimatedFee)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _WithdrawalLabel('Narration (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: narration,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 12),
            decoration: _tumiziInputDecoration(theme).copyWith(
              hintText: 'Enter reason or reference for this withdrawal...',
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving || !_canWithdraw ? null : onSubmit,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: const Text('Confirm withdrawal'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalChargeTiersCard extends StatelessWidget {
  const _WithdrawalChargeTiersCard();

  static const _tiers = [
    ('1 - 100', 'KES 0.00'),
    ('101 - 500', 'KES 6.00'),
    ('501 - 1,000', 'KES 12.00'),
    ('1,001 - 1,500', 'KES 20.00'),
    ('1,501 - 2,500', 'KES 30.00'),
    ('2,501 - 5,000', 'KES 40.00'),
    ('5,001 - 10,000', 'KES 55.00'),
    ('10,001 - 35,000', 'KES 60.00'),
    ('35,001 - 250,000', 'KES 68.00'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.primary,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal charge tiers',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Fees are deducted automatically from each withdrawal.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _ChargeTierRow(range: 'Range (KES)', fee: 'Fee', header: true),
          for (final tier in _tiers)
            _ChargeTierRow(range: tier.$1, fee: tier.$2),
        ],
      ),
    );
  }
}

class _ChargeTierRow extends StatelessWidget {
  const _ChargeTierRow({
    required this.range,
    required this.fee,
    this.header = false,
  });

  final String range;
  final String fee;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: header ? theme.colorScheme.surfaceContainerHigh : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              range,
              style: GoogleFonts.inter(
                fontSize: header ? 10 : 12,
                fontWeight: header ? FontWeight.w800 : FontWeight.w600,
                color: header
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary
                  .withValues(alpha: header ? 0 : 0.08),
              borderRadius: BorderRadius.circular(6),
              border: header
                  ? null
                  : Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18)),
            ),
            child: Text(
              fee,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: header
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentWithdrawalActivity extends StatelessWidget {
  const _RecentWithdrawalActivity({required this.activity});

  final List<Map<String, dynamic>> activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent activity',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showTumiziMessage(
                    context,
                    'Transaction history will be available soon.',
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View all'),
                ),
              ],
            ),
          ),
          Container(
            color: theme.colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _ActivityHeader('Created'),
                _ActivityHeader('Amount'),
                _ActivityHeader('Status'),
                _ActivityHeader('Withdraw ref'),
              ],
            ),
          ),
          if (activity.isEmpty)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                'Use the refresh control next to your balance to load recent withdrawal activity from Tumizi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in activity.take(5))
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _ActivityCell(
                        _pick([item], ['createdAt', 'created_at', 'date'])),
                    _ActivityCell(_money([item])),
                    _ActivityCell(_pick([item], ['status', 'state'])),
                    _ActivityCell(_pick([item],
                        ['withdrawRef', 'withdraw_ref', 'reference', 'id'])),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActivityCell extends StatelessWidget {
  const _ActivityCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _WithdrawalNoteCard extends StatelessWidget {
  const _WithdrawalNoteCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFDCFCE7),
            foregroundColor: const Color(0xFF16A34A),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalLabel extends StatelessWidget {
  const _WithdrawalLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TumiziOverviewCard extends StatelessWidget {
  const _TumiziOverviewCard({required this.status, required this.items});

  final String status;
  final List<_TumiziInfoItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merchant account overview',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live details from Tumizi merchant API.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 16),
          _TumiziInfoGrid(items: items),
        ],
      ),
    );
  }
}

class _TumiziInfoSection extends StatelessWidget {
  const _TumiziInfoSection({required this.title, required this.items});

  final String title;
  final List<_TumiziInfoItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 14),
          _TumiziInfoGrid(items: items),
        ],
      ),
    );
  }
}

class _TumiziInfoGrid extends StatelessWidget {
  const _TumiziInfoGrid({required this.items});

  final List<_TumiziInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _TumiziInfoTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _TumiziInfoTile extends StatelessWidget {
  const _TumiziInfoTile({required this.item});

  final _TumiziInfoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 9,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(
          item.value.isEmpty ? '-' : item.value,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final active = normalized == 'active' || normalized == 'true';
    final color = active
        ? const Color(0xFF16A34A)
        : Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status == '-' ? 'UNKNOWN' : status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TumiziInfoItem {
  const _TumiziInfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _TumiziErrorState extends StatelessWidget {
  const _TumiziErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
