import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

/// Order detail — Stitch: Order Details (items card, timeline, quick actions).
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderKey,
  });

  final String orderKey;

  static const Color _navyTitle = Color(0xFF001790);
  static const Color _priceBlue = Color(0xFF0033AD);
  static const Color _itemTileBg = Color(0xFFF0F1F6);
  static const Color _premiumBadgeBg = Color(0xFFE8EEFF);

  static final Map<String, _OrderDetailData> _demo = {
    'DK-9821': _stitchDefaultDetail,
    'DK-9819': _OrderDetailData(
      code: 'DK-9819',
      itemsCategorySubtitle: '1 item from Watches',
      premiumCustomer: false,
      lineItems: const [
        _LineItem(
          name: 'Minimalist Slate Watch',
          variantQty: 'Graphite • Qty: 1',
          price: '\$89.50',
          thumbColor: Color(0xFF4A5568),
        ),
      ],
      subtotal: '\$89.50',
      shipping: '\$8.00',
      tax: '\$7.80',
      total: '\$105.30',
      timeline: const [
        _TimelineStep(
          title: 'Order Received',
          subtitleLines: ['Oct 24, 2025 • 9:05 AM'],
          state: _StepState.done,
        ),
        _TimelineStep(
          title: 'Payment Confirmed',
          subtitleLines: ['Oct 24, 2025 • 9:06 AM', 'via Stripe'],
          state: _StepState.done,
        ),
        _TimelineStep(
          title: 'Processing Order',
          subtitleLines: ['Oct 24, 2025 • 9:10 AM'],
          state: _StepState.current,
        ),
        _TimelineStep(
          title: 'Shipped',
          subtitleLines: ['Pending action'],
          state: _StepState.upcoming,
        ),
      ],
    ),
    'DK-9815': _OrderDetailData(
      code: 'DK-9815',
      itemsCategorySubtitle: '2 items from Audio',
      premiumCustomer: true,
      lineItems: const [
        _LineItem(
          name: 'Studio Pro Wireless',
          variantQty: 'Matte Black • Qty: 2',
          price: '\$398.00',
          thumbColor: Color(0xFF2D3748),
        ),
      ],
      subtotal: '\$398.00',
      shipping: '\$0.00',
      tax: '\$31.84',
      total: '\$429.84',
      timeline: const [
        _TimelineStep(
          title: 'Order Received',
          subtitleLines: ['Oct 23, 2025 • 4:28 PM'],
          state: _StepState.done,
        ),
        _TimelineStep(
          title: 'Payment Confirmed',
          subtitleLines: ['Oct 23, 2025 • 4:29 PM', 'via Stripe'],
          state: _StepState.done,
        ),
        _TimelineStep(
          title: 'Processing Order',
          subtitleLines: ['Oct 23, 2025 • 4:35 PM'],
          state: _StepState.done,
        ),
        _TimelineStep(
          title: 'Shipped',
          subtitleLines: ['Oct 23, 2025 • 6:12 PM', 'FedEx • Tracking sent'],
          state: _StepState.done,
        ),
      ],
    ),
    'DK-9810': _OrderDetailData(
      code: 'DK-9810',
      itemsCategorySubtitle: '1 item from Accessories',
      premiumCustomer: false,
      lineItems: const [
        _LineItem(
          name: 'Golden Aviators',
          variantQty: 'Amber • Qty: 2',
          price: '\$45.00',
          thumbColor: Color(0xFFB7791F),
        ),
      ],
      subtotal: '\$45.00',
      shipping: '\$5.99',
      tax: '\$4.08',
      total: '\$55.07',
      timeline: const [
        _TimelineStep(
          title: 'Order Received',
          subtitleLines: ['Oct 23, 2025 • 11:12 AM'],
          state: _StepState.done,
        ),
        _TimelineStep(
          title: 'Payment Confirmed',
          subtitleLines: ['Pending'],
          state: _StepState.current,
        ),
        _TimelineStep(
          title: 'Processing Order',
          subtitleLines: ['Pending action'],
          state: _StepState.upcoming,
        ),
        _TimelineStep(
          title: 'Shipped',
          subtitleLines: ['Pending action'],
          state: _StepState.upcoming,
        ),
      ],
    ),
  };

  static const _OrderDetailData _stitchDefaultDetail = _OrderDetailData(
    code: 'DK-9821',
    itemsCategorySubtitle: '3 items from Electronics & Accessories',
    premiumCustomer: true,
    lineItems: [
      _LineItem(
        name: 'Pro Wireless Headphones',
        variantQty: 'Midnight Blue • Qty: 1',
        price: '\$299.00',
        thumbColor: Color(0xFF2B4C7E),
      ),
      _LineItem(
        name: 'Portable Power Bank',
        variantQty: 'Space Grey • Qty: 1',
        price: '\$89.00',
        thumbColor: Color(0xFF718096),
      ),
      _LineItem(
        name: 'USB-C Fast Charger',
        variantQty: 'White • Qty: 1',
        price: '\$24.00',
        thumbColor: Color(0xFFE2E8F0),
      ),
    ],
    subtotal: '\$412.00',
    shipping: '\$15.00',
    tax: '\$12.68',
    total: '\$439.68',
    timeline: [
      _TimelineStep(
        title: 'Order Received',
        subtitleLines: ['Oct 24, 2025 • 10:12 AM'],
        state: _StepState.done,
      ),
      _TimelineStep(
        title: 'Payment Confirmed',
        subtitleLines: ['Oct 24, 2025 • 10:14 AM', 'via Stripe'],
        state: _StepState.done,
      ),
      _TimelineStep(
        title: 'Processing Order',
        subtitleLines: ['Started Oct 24, 2025 • 10:18 AM'],
        state: _StepState.current,
      ),
      _TimelineStep(
        title: 'Shipped',
        subtitleLines: ['Pending action'],
        state: _StepState.upcoming,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _demo[orderKey] ??
        _OrderDetailData(
          code: orderKey,
          itemsCategorySubtitle: 'Items',
          premiumCustomer: false,
          lineItems: const [],
          subtotal: '\$0.00',
          shipping: '\$0.00',
          tax: '\$0.00',
          total: '\$0.00',
          timeline: const [],
        );

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => context.pop(),
                    color: _navyTitle,
                  ),
                  Expanded(
                    child: Text(
                      'Order #${data.code}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _navyTitle,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  ClipOval(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=128&h=128&fit=crop',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36,
                        height: 36,
                        color: _premiumBadgeBg,
                        alignment: Alignment.center,
                        child: Icon(Icons.person_rounded, color: _priceBlue.withValues(alpha: 0.8), size: 22),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _itemsCard(context, data),
                const SizedBox(height: 14),
                _timelineCard(context, data),
                const SizedBox(height: 14),
                _quickActionsCard(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(BuildContext context, _OrderDetailData data) {
    final theme = Theme.of(context);
    final onCard = theme.colorScheme.onSurfaceVariant;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items Ordered',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.itemsCategorySubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onCard,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.premiumCustomer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _premiumBadgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PREMIUM CUSTOMER',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _priceBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.lineItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _itemRow(theme, item),
                )),
            const SizedBox(height: 8),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            _priceRow(theme, 'Subtotal', data.subtotal, isTotal: false, onCard: onCard),
            const SizedBox(height: 8),
            _priceRow(theme, 'Shipping (Standard)', data.shipping, isTotal: false, onCard: onCard),
            const SizedBox(height: 8),
            _priceRow(theme, 'Estimated Tax', data.tax, isTotal: false, onCard: onCard),
            const SizedBox(height: 12),
            _priceRow(theme, 'Total', data.total, isTotal: true, onCard: onCard),
          ],
        ),
      ),
    );
  }

  static Widget _itemRow(ThemeData theme, _LineItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _itemTileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.thumbColor,
                    Color.lerp(item.thumbColor, Colors.black, 0.15)!,
                  ],
                ),
              ),
              child: Icon(Icons.inventory_2_outlined, color: Colors.white.withValues(alpha: 0.9), size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _navyTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.variantQty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.price,
            style: theme.textTheme.titleSmall?.copyWith(
              color: _priceBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _priceRow(
    ThemeData theme,
    String label,
    String value, {
    required bool isTotal,
    required Color onCard,
  }) {
    if (isTotal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _navyTitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: _priceBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: onCard),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _timelineCard(BuildContext context, _OrderDetailData data) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Processing Timeline',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _Timeline(steps: data.timeline),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.local_shipping_outlined, size: 22),
              label: const Text('Mark as Shipped'),
              style: FilledButton.styleFrom(
                backgroundColor: _priceBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitleLines,
    required this.state,
  });

  final String title;
  final List<String> subtitleLines;
  final _StepState state;
}

class _LineItem {
  const _LineItem({
    required this.name,
    required this.variantQty,
    required this.price,
    required this.thumbColor,
  });

  final String name;
  final String variantQty;
  final String price;
  final Color thumbColor;
}

class _OrderDetailData {
  const _OrderDetailData({
    required this.code,
    required this.itemsCategorySubtitle,
    required this.premiumCustomer,
    required this.lineItems,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.timeline,
  });

  final String code;
  final String itemsCategorySubtitle;
  final bool premiumCustomer;
  final List<_LineItem> lineItems;
  final String subtotal;
  final String shipping;
  final String tax;
  final String total;
  final List<_TimelineStep> timeline;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});

  final List<_TimelineStep> steps;

  static const Color _lineBlue = Color(0xFF0033AD);
  static const Color _lineMuted = Color(0xFFE0E2EC);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        final showLine = !isLast;
        final lineActive = step.state == _StepState.done;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Column(
                children: [
                  _StepDot(state: step.state),
                  if (showLine)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 2,
                      height: 40,
                      color: lineActive ? _lineBlue : _lineMuted,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: step.state == _StepState.upcoming
                            ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                            : OrderDetailScreen._navyTitle,
                      ),
                    ),
                    ...step.subtitleLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: step.state == _StepState.upcoming
                                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.state});

  final _StepState state;

  static const Color _blue = Color(0xFF0033AD);

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: _blue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _blue, width: 2.5),
            color: Colors.white,
          ),
          child: Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
            ),
          ),
        );
      case _StepState.upcoming:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade400,
              width: 2,
            ),
            color: Colors.white,
          ),
        );
    }
  }
}
