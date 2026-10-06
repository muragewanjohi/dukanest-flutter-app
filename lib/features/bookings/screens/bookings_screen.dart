import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

/// Real scheduling/booking (S2, docs/SERVICES_PLAN.md) — merchant-facing
/// bookings management. Date-navigator + day-list (no calendar-grid widget
/// — mirrors the web dashboard's own choice to avoid one; no such
/// dependency exists in pubspec.yaml and the project has consistently
/// avoided adding one for comparable date UI).
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

const List<String> _statusOptions = <String>[
  'all',
  'pending',
  'confirmed',
  'completed',
  'cancelled',
  'no_show',
];

String _statusLabel(String s) {
  switch (s) {
    case 'all':
      return 'All statuses';
    case 'no_show':
      return 'No-show';
    default:
      return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'confirmed':
      return AppTheme.primaryDark;
    case 'completed':
      return Colors.green.shade700;
    case 'cancelled':
    case 'no_show':
      return Colors.redAccent;
    default:
      return Colors.orange.shade700;
  }
}

String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String _date = _todayStr();
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String? _error;
  String? _updatingId;

  List<Map<String, dynamic>> _bookableProducts = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _loadBookableProducts();
  }

  Future<void> _loadBookableProducts() async {
    final api = ref.read(apiClientProvider);
    final response = await api.getProducts(page: 1, limit: 100);
    if (!response.success || response.data == null || !mounted) return;
    var data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      data = data['data'];
    }
    final list = data is Map<String, dynamic>
        ? (data['products'] ?? data['items'])
        : null;
    if (list is! List) return;
    setState(() {
      _bookableProducts = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => p['is_bookable'] == true || p['isBookable'] == true)
          .toList();
    });
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(apiClientProvider);
    final response = await api.getBookings(
      date: _date,
      status: _statusFilter == 'all' ? null : _statusFilter,
      limit: 100,
    );
    if (!mounted) return;
    if (!response.success) {
      setState(() {
        _loading = false;
        _error = response.error?.message ?? 'Failed to load bookings';
      });
      return;
    }
    var data = response.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      data = data['data'];
    }
    final list = data is Map<String, dynamic>
        ? (data['bookings'] ?? data['items'])
        : null;
    setState(() {
      _bookings = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
      _loading = false;
    });
  }

  void _shiftDate(int deltaDays) {
    final d = DateTime.parse('${_date}T00:00:00.000Z').add(Duration(days: deltaDays));
    setState(() => _date = d.toIso8601String().substring(0, 10));
    _loadBookings();
  }

  Future<void> _updateStatus(String id, String status) async {
    setState(() => _updatingId = id);
    final api = ref.read(apiClientProvider);
    final response = await api.patchBooking(id, {'status': status});
    if (!mounted) return;
    setState(() => _updatingId = null);
    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error?.message ?? 'Failed to update booking')),
      );
      return;
    }
    _loadBookings();
  }

  Future<void> _cancelBooking(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Cancel booking')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _updatingId = id);
    final api = ref.read(apiClientProvider);
    final response = await api.cancelBooking(id);
    if (!mounted) return;
    setState(() => _updatingId = null);
    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error?.message ?? 'Failed to cancel booking')),
      );
      return;
    }
    _loadBookings();
  }

  Future<void> _openAddBookingDialog() async {
    if (_bookableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No bookable services yet — turn one on from a product\'s edit screen first.')),
      );
      return;
    }

    String? productId;
    var date = _todayStr();
    List<Map<String, dynamic>> slots = [];
    String? startTime;
    var slotsLoading = false;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var busy = false;

    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> loadSlots() async {
                if (productId == null) return;
                setDialogState(() => slotsLoading = true);
                final api = ref.read(apiClientProvider);
                final response = await api.getBookingAvailability(productId!, date);
                if (!dialogContext.mounted) return;
                var data = response.data;
                if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
                  data = data['data'];
                }
                final rawSlots = data is Map<String, dynamic> ? data['slots'] : null;
                setDialogState(() {
                  slots = rawSlots is List
                      ? rawSlots.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                      : [];
                  slotsLoading = false;
                });
              }

              Future<void> submit() async {
                if (productId == null || startTime == null) return;
                setDialogState(() => busy = true);
                final api = ref.read(apiClientProvider);
                final response = await api.createBooking({
                  'product_id': productId,
                  'date': date,
                  'start_time': startTime,
                  'customer_name': nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                  'customer_phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                });
                if (!dialogContext.mounted) return;
                if (!response.success) {
                  setDialogState(() => busy = false);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(response.error?.message ?? 'Failed to create booking')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              }

              return AlertDialog(
                title: const Text('Add Booking'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: productId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Service'),
                        items: _bookableProducts
                            .map((p) => DropdownMenuItem(
                                  value: p['id']?.toString(),
                                  child: Text(p['name']?.toString() ?? 'Service'),
                                ))
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) {
                                setDialogState(() {
                                  productId = v;
                                  startTime = null;
                                });
                                loadSlots();
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Date'),
                        controller: TextEditingController(text: date),
                        onTap: busy
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: DateTime.parse('${date}T00:00:00.000Z'),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    date = picked.toIso8601String().substring(0, 10);
                                    startTime = null;
                                  });
                                  loadSlots();
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      if (slotsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Loading available times...'),
                        )
                      else if (productId != null && slots.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No available times on this date.'),
                        )
                      else if (slots.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots.map((slot) {
                            final t = slot['startTime']?.toString() ?? '';
                            final selected = startTime == t;
                            return ChoiceChip(
                              label: Text(t),
                              selected: selected,
                              onSelected: busy ? null : (_) => setDialogState(() => startTime = t),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        enabled: !busy,
                        decoration: const InputDecoration(labelText: 'Customer name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneCtrl,
                        enabled: !busy,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: (busy || productId == null || startTime == null) ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (created == true && mounted) {
        setState(() => _date = date);
        _loadBookings();
      }
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Bookings'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBookingDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Booking'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _shiftDate(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _date,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shiftDate(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _date = _todayStr());
                        _loadBookings();
                      },
                      child: const Text('Today'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _statusOptions.map((s) {
                      final selected = _statusFilter == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _statusFilter = s);
                            _loadBookings();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ApiErrorView(
                        error: _error!,
                        title: 'Could not load bookings',
                        onRetry: _loadBookings,
                      )
                    : _bookings.isEmpty
                        ? const Center(child: Text('No bookings on this date.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _bookings.length,
                            itemBuilder: (context, index) {
                              final b = _bookings[index];
                              final id = b['id']?.toString() ?? '';
                              final status = b['status']?.toString() ?? 'pending';
                              final updating = _updatingId == id;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 16, color: theme.colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${b['start_time'] ?? ''} – ${b['end_time'] ?? ''}',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _statusLabel(status),
                                              style: TextStyle(
                                                  color: _statusColor(status),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(b['product_name']?.toString() ?? 'Service'),
                                      Text(
                                        [
                                          b['customer_name']?.toString() ?? 'No name',
                                          if ((b['customer_phone'] as String?)?.isNotEmpty == true)
                                            b['customer_phone'],
                                          if ((b['staff_label'] as String?)?.isNotEmpty == true)
                                            b['staff_label'],
                                        ].join(' • '),
                                        style: TextStyle(
                                            color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (status == 'pending')
                                            OutlinedButton(
                                              onPressed: updating ? null : () => _updateStatus(id, 'confirmed'),
                                              child: const Text('Confirm'),
                                            ),
                                          if (status == 'pending' || status == 'confirmed') ...[
                                            OutlinedButton(
                                              onPressed: updating ? null : () => _updateStatus(id, 'completed'),
                                              child: const Text('Complete'),
                                            ),
                                            OutlinedButton(
                                              onPressed: updating ? null : () => _updateStatus(id, 'no_show'),
                                              child: const Text('No-show'),
                                            ),
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                              onPressed: updating ? null : () => _cancelBooking(id),
                                              child: const Text('Cancel'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
