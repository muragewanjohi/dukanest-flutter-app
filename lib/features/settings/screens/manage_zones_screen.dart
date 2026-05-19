import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../dashboard/providers/dashboard_local_onboarding_provider.dart';
import '../providers/dashboard_settings_provider.dart';
import '../providers/delivery_zones_provider.dart';
import 'delivery_zone_editor_screen.dart';

/// Manage shipping zones — Stitch: Manage Zones (Mobile) (14c6d52470234cb1bf3b502e4ebf4e22).
class ManageZonesScreen extends ConsumerStatefulWidget {
  const ManageZonesScreen({super.key});

  @override
  ConsumerState<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends ConsumerState<ManageZonesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor({
    DeliveryZoneEditorArgs? args,
  }) async {
    final ctx = context;
    final inTutorialFlow =
        GoRouterState.of(ctx).uri.queryParameters['tutorial'] == '1';
    final nextArgs = DeliveryZoneEditorArgs(
      zoneKey: args?.zoneKey,
      initialName: args?.initialName,
      initialAreas: args?.initialAreas,
      initialFeeKes: args?.initialFeeKes,
      initialFreeOverKes: args?.initialFreeOverKes,
      initialHandlingDays: args?.initialHandlingDays,
      initialIsDefault: args?.initialIsDefault ?? false,
      returnToTutorialOnCreate: inTutorialFlow,
    );
    await ctx.push(
      inTutorialFlow ? '/shipping-zone-editor?tutorial=1' : '/shipping-zone-editor',
      extra: nextArgs,
    );
    if (!mounted) return;
    ref.invalidate(deliveryZonesListProvider);
    ref.invalidate(dashboardSettingsProvider);
  }

  bool _zoneMatchesQuery(Map<String, dynamic> z, String q) {
    if (q.isEmpty) return true;
    final name = zoneName(z).toLowerCase();
    if (name.contains(q)) return true;
    for (final a in zoneAreasFromMap(z)) {
      if (a.toLowerCase().contains(q)) return true;
    }
    final fee = zoneFee(z).toStringAsFixed(0);
    if (fee.contains(q)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zonesAsync = ref.watch(deliveryZonesListProvider);
    final q = _searchController.text.trim().toLowerCase();

    return zonesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(title: 'Manage Zones'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: const DashboardAppBar(title: 'Manage Zones'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(deliveryZonesListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (zones) {
        if (zones.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(dashboardLocalStepCompletionsProvider.notifier).markComplete(
                  DashboardOnboardingStepKeys.shipping,
                );
          });
        }
        final filtered = q.isEmpty
            ? zones
            : zones
                .where((z) => _zoneMatchesQuery(z, q))
                .toList();

        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: DashboardAppBar(
            title: 'Manage Zones',
            actions: [
              IconButton(
                icon: Icon(Icons.add_rounded, color: AppTheme.primaryDark),
                onPressed: () => _openEditor(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            children: [
              Text(
                'Delivery zones',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Group locations into zones and assign a delivery fee for each. Customers see the fee that matches their address.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Zone A: UpperHill, Town CBD — KES 250',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Zone B: Westlands, Highridge — KES 350',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search zones…',
                  hintStyle: GoogleFonts.inter(color: theme.colorScheme.outlineVariant),
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Once delivery zones are set, checkout only proceeds when the customer\'s address '
                        'falls inside a zone. Orders outside every zone are not processed—the shopper is '
                        'told you are not currently delivering to their location. For example, if your zones '
                        'only cover UpperHill, Town CBD, and Westlands, an order from Kitui cannot proceed.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.45,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (filtered.isEmpty && zones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No zones match your search.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ...filtered.map((z) {
                final name = zoneName(z);
                final areas = zoneAreasFromMap(z);
                final fee = zoneFee(z);
                final summary = areas.isEmpty
                    ? 'No locations configured'
                    : areas.length <= 3
                        ? areas.join(', ')
                        : '${areas.take(3).join(', ')}…';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLowest,
                    elevation: 0,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _openEditor(
                        args: DeliveryZoneEditorArgs(
                          zoneKey: zoneId(z),
                          initialName: name,
                          initialAreas: List<String>.from(areas),
                          initialFeeKes: fee.toStringAsFixed(0),
                          initialFreeOverKes: zoneFreeOver(z).toStringAsFixed(0),
                          initialHandlingDays: zoneHandlingDays(z).toString(),
                          initialIsDefault: zoneIsDefault(z),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.map_outlined, color: AppTheme.primaryDark, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (zoneIsDefault(z))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'DEFAULT',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: theme.colorScheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    summary,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'KES ${fee.toStringAsFixed(0)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outlineVariant),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _openEditor(),
                icon: Icon(Icons.add_rounded, color: AppTheme.primaryDark),
                label: Text(
                  'Add delivery zone',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.primaryDark.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
