import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryCards = <({String label, String value, String delta, IconData icon})>[
      (label: 'Active Orders', value: '24', delta: 'PENDING', icon: Icons.shopping_bag_outlined),
      (label: 'Last 30 days', value: '182', delta: 'COMPLETED', icon: Icons.check_circle_outline),
    ];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
              const SizedBox(width: 10),
              Text(
                'DukaNest',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF001790),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(Icons.notifications, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'OVERVIEW',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Welcome back, Sarah',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Getting Started', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('2 of 4 steps completed', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: 0.5,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 12),
                  const _StepRow(
                    completed: true,
                    title: 'Add your first product',
                    action: 'Edit',
                  ),
                  const _StepRow(
                    completed: false,
                    title: 'Configure payment settings',
                    action: 'Set Up',
                  ),
                  const _StepRow(
                    completed: true,
                    title: 'Customize store design',
                    action: 'View',
                  ),
                  const _StepRow(
                    completed: false,
                    title: 'Share your store link',
                    action: 'Share',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFEDECF6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Weekly Revenue', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('7 DAYS', style: theme.textTheme.labelSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('+12.5% from last week', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 70,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        _MiniBar(height: 18),
                        SizedBox(width: 6),
                        _MiniBar(height: 26),
                        SizedBox(width: 6),
                        _MiniBar(height: 12),
                        SizedBox(width: 6),
                        _MiniBar(height: 44, highlighted: true),
                        SizedBox(width: 6),
                        _MiniBar(height: 23),
                        SizedBox(width: 6),
                        _MiniBar(height: 31),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$12,450.00',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text('Total earned', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: summaryCards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: Icon(card.icon),
                        title: Text(card.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: Text(card.label),
                        trailing: Text(
                          card.delta,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Stock Alerts', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ACTION REQUIRED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Organic Coffee Beans'),
              subtitle: const Text('Only 2 units left', style: TextStyle(color: Color(0xFFBA1A1A))),
              trailing: TextButton(onPressed: () {}, child: const Text('Restock')),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Almond Milk 1L'),
              subtitle: const Text('Only 5 units left', style: TextStyle(color: Color(0xFFBA1A1A))),
              trailing: TextButton(onPressed: () {}, child: const Text('Restock')),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF001790), Color(0xFF0025CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grow your store', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Add new products or explore marketing insights.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: const [
                      _QuickActionChip(icon: Icons.add, label: 'Add Product', invert: true),
                      _QuickActionChip(icon: Icons.receipt_long_outlined, label: 'View Orders', invert: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    this.invert = false,
  });

  final IconData icon;
  final String label;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () {},
      style: FilledButton.styleFrom(
        backgroundColor: invert ? Colors.white.withValues(alpha: 0.95) : null,
        foregroundColor: invert ? const Color(0xFF001790) : null,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.completed,
    required this.title,
    required this.action,
  });

  final bool completed;
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    final isPrimaryAction = !completed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFFF4F8F4) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: completed
                ? const Color(0xFF15A85B).withValues(alpha: 0.55)
                : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: completed ? const Color(0xFF15A85B) : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(decoration: completed ? TextDecoration.lineThrough : TextDecoration.none),
              ),
            ),
            if (isPrimaryAction)
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0025CC),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 36),
                ),
                child: Text(action),
              )
            else
              TextButton(onPressed: () {}, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.height,
    this.highlighted = false,
  });

  final double height;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: height,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF0025CC) : const Color(0xFFD9D9E2),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}
