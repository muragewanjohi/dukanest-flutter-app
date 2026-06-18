import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';

/// Bottom sheet: collect phone, initiate Tumizi partner subscription STK, poll status.
class TumiziCheckoutSheet extends ConsumerStatefulWidget {
  const TumiziCheckoutSheet({
    super.key,
    required this.planId,
    this.planTitle,
  });

  final String planId;
  final String? planTitle;

  static Future<bool?> show(
    BuildContext context, {
    required String planId,
    String? planTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: TumiziCheckoutSheet(planId: planId, planTitle: planTitle),
      ),
    );
  }

  @override
  ConsumerState<TumiziCheckoutSheet> createState() => _TumiziCheckoutSheetState();
}

class _TumiziCheckoutSheetState extends ConsumerState<TumiziCheckoutSheet> {
  final _phoneCtrl = TextEditingController(text: '254');
  bool _busy = false;
  String? _error;
  String? _hint;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    final raw = _phoneCtrl.text.trim();
    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    if (normalized.length < 9) {
      setState(() => _error = 'Enter a valid M-Pesa number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _hint = 'Sending payment request…';
    });

    try {
      final api = ref.read(apiClientProvider);
      final initiate = await api.initiateSubscriptionTumizi({
        'planId': widget.planId,
        'plan_id': widget.planId,
        'phoneNumber': normalized,
        'phone_number': normalized,
      });

      final body = _unwrap(initiate.data);
      if (!initiate.success || body == null) {
        setState(() {
          _busy = false;
          _error = initiate.error?.message ?? 'Could not start Tumizi checkout';
          _hint = null;
        });
        return;
      }

      final externalRef = _firstString(body, const [
        'externalReference',
        'external_reference',
        'checkoutRequestId',
        'checkout_request_id',
      ]);
      if (externalRef == null || externalRef.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Unexpected response from server';
          _hint = null;
        });
        return;
      }

      setState(() => _hint = 'Check your phone to approve payment…');

      _schedulePoll(api, externalRef);
    } catch (e, st) {
      debugPrint('$e\n$st');
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Try again.';
        _hint = null;
      });
    }
  }

  void _schedulePoll(ApiClient api, String externalReference) {
    _pollTimer?.cancel();
    var attempts = 0;
    const maxAttempts = 36;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (attempts > maxAttempts) {
        timer.cancel();
        setState(() {
          _busy = false;
          _hint = null;
          _error =
              'Payment still pending — open Subscription again shortly to refresh.';
        });
        return;
      }

      try {
        final res = await api.getSubscriptionTumiziStatus(externalReference);
        final raw = _unwrap(res.data);

        final statusNorm = _statusFromMaps([
          raw,
          raw?['status'] is Map
              ? Map<String, dynamic>.from(raw!['status'] as Map)
              : null,
          raw?['payment'] is Map
              ? Map<String, dynamic>.from(raw!['payment'] as Map)
              : null,
          raw?['paymentLog'] is Map
              ? Map<String, dynamic>.from(raw!['paymentLog'] as Map)
              : null,
          raw?['data'] is Map
              ? Map<String, dynamic>.from(raw!['data'] as Map)
              : null,
        ]);

        if (_isComplete(statusNorm)) {
          timer.cancel();
          if (mounted) Navigator.of(context).pop<bool>(true);
          return;
        }
        if (_isFailed(statusNorm)) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _busy = false;
              _hint = null;
              _error = _failureMessage(raw) ?? 'Payment was not completed';
            });
          }
        }
      } catch (_) {
        // Retry until max attempts.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 16,
        bottom: 22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'M-Pesa via Tumizi',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
          if ((widget.planTitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.planTitle!.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'M-Pesa phone',
              helperText: 'Use 2547… or drop leading 0',
              filled: true,
              fillColor: AppTheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ),
          if (_error != null && _error!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_hint != null && _hint!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _startCheckout,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send STK prompt'),
          ),
          TextButton(
            onPressed:
                _busy ? null : () => Navigator.of(context).pop<bool>(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _unwrap(dynamic data) {
  if (data is! Map) return null;
  final outer = Map<String, dynamic>.from(data);
  final inner = outer['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return outer;
}

String? _firstString(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  }
  return null;
}

String? _statusFromMaps(List<Map<String, dynamic>?> maps) {
  for (final m in maps) {
    if (m == null) continue;
    final candidates = [
      _firstString(m, [
        'status',
        'paymentStatus',
        'payment_status',
      ]),
      _firstString(m, [
        'resultDescription',
        'description',
        'message',
      ]),
    ];
    for (final s in candidates) {
      if (s == null) continue;
      final t = s.trim().toLowerCase();
      if (t.isEmpty) continue;
      return t;
    }
  }
  return null;
}

bool _isComplete(String? s) {
  if (s == null) return false;
  return s.contains('complete') ||
      s == 'paid' ||
      s == 'success' ||
      s.contains('success');
}

bool _isFailed(String? s) {
  if (s == null) return false;
  return s.contains('fail') ||
      s.contains('cancel') ||
      s.contains('error') ||
      s == 'timeout' ||
      s.contains('denied');
}

String? _failureMessage(Map<String, dynamic>? raw) {
  if (raw == null) return null;
  final fromRoot = _firstString(raw, [
    'message',
    'errorMessage',
    'error_message',
    'detail',
    'reason',
  ]);
  final inner = raw['error'];
  final fromNested = inner is Map
      ? _firstString(Map<String, dynamic>.from(inner), [
          'message',
          'detail',
        ])
      : null;
  return fromNested ?? fromRoot;
}
