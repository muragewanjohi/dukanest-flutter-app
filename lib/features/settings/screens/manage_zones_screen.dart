import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import 'delivery_zone_editor_screen.dart';

/// Manage shipping zones — Stitch: Manage Zones (Mobile) (14c6d52470234cb1bf3b502e4ebf4e22).
class ManageZonesScreen extends StatelessWidget {
  const ManageZonesScreen({super.key});

  static const _zones = <({
    String key,
    String name,
    String areasSummary,
    List<String> areas,
    String feeLabel,
    String feeKes,
    String freeOverKes,
    String handlingDays,
    bool isDefault,
  })>[
    (
      key: 'nairobi',
      name: 'Nairobi Metro',
      areasSummary: 'Nairobi, Kiambu — 12 sub-areas',
      areas: ['Nairobi', 'Kiambu', 'Westlands', 'Karen', 'Runda', 'Thika Road'],
      feeLabel: 'KES 200',
      feeKes: '200',
      freeOverKes: '5000',
      handlingDays: '1',
      isDefault: true,
    ),
    (
      key: 'coastal',
      name: 'Coastal corridor',
      areasSummary: 'Mombasa, Kilifi, Kwale',
      areas: ['Mombasa', 'Kilifi', 'Kwale', 'Diani', 'Nyali'],
      feeLabel: 'KES 450',
      feeKes: '450',
      freeOverKes: '0',
      handlingDays: '2',
      isDefault: false,
    ),
    (
      key: 'western',
      name: 'Western highlands',
      areasSummary: 'Kisumu, Kakamega, Eldoret',
      areas: ['Kisumu', 'Kakamega', 'Eldoret', 'Bungoma'],
      feeLabel: 'KES 380',
      feeKes: '380',
      freeOverKes: '0',
      handlingDays: '2',
      isDefault: false,
    ),
  ];

  void _openEditor(BuildContext context, {DeliveryZoneEditorArgs? args}) {
    context.push('/shipping-zone-editor', extra: args);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryDark, size: 26),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Manage Zones',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppTheme.primaryDark),
            onPressed: () => _openEditor(context),
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
            'Group counties or areas into zones and assign a delivery fee for each. Customers see the fee that matches their address.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
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
            onChanged: (_) {},
          ),
          const SizedBox(height: 20),
          ..._zones.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: theme.colorScheme.surfaceContainerLowest,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _openEditor(
                      context,
                      args: DeliveryZoneEditorArgs(
                        zoneKey: z.key,
                        initialName: z.name,
                        initialAreas: List<String>.from(z.areas),
                        initialFeeKes: z.feeKes,
                        initialFreeOverKes: z.freeOverKes,
                        initialHandlingDays: z.handlingDays,
                        initialIsDefault: z.isDefault,
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
                                        z.name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (z.isDefault)
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
                                  z.areasSummary,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  z.feeLabel,
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
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openEditor(context),
            icon: Icon(Icons.add_rounded, color: AppTheme.primaryDark),
            label: Text(
              'Add shipping zone',
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
  }
}
