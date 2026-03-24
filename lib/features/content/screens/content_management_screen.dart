import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

/// Content Manager — Stitch: Content Management (Updated Nav & Sales).
class ContentManagementScreen extends StatelessWidget {
  const ContentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Content Manager', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: SearchBar(
                  hintText: 'Search',
                  leading: const Icon(Icons.search),
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, size: 20),
                    SizedBox(width: 6),
                    Text('Filter'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Create New Post'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Recent Blog Posts', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 8),
          _BlogCard(
            status: 'PUBLISHED',
            title: 'How to source the best organic produce for your store',
            meta: 'Updated 2 days ago • 5 min read',
          ),
          _BlogCard(
            status: 'DRAFT',
            title: 'Modernizing your checkout: Why digital payments matter',
            meta: 'Edited 5 hours ago',
          ),
          _BlogCard(
            status: 'PUBLISHED',
            title: 'Customer loyalty programs that actually work',
            meta: 'Updated 1 week ago • 8 min read',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Pages', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const SizedBox(height: 8),
          _PageRow(title: 'About Us', updated: 'Last updated: Mar 12, 2024'),
          _PageRow(title: 'Privacy Policy', updated: 'Last updated: Jan 05, 2024'),
          _PageRow(title: 'Terms of Service', updated: 'Last updated: Feb 20, 2024'),
          const SizedBox(height: 24),
          Text('Active Sales', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Row(
                children: [
                  Chip(
                    label: const Text('ACTIVE'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Summer Flash Sale: 20% Off Storewide')),
                ],
              ),
              trailing: TextButton(onPressed: () => context.push('/sales-editor'), child: const Text('Edit')),
            ),
          ),
          Card(
            child: ListTile(
              title: Row(
                children: [
                  Chip(
                    label: const Text('ACTIVE'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Buy 2 Get 1 Free: Organic Greens')),
                ],
              ),
              trailing: TextButton(onPressed: () => context.push('/sales-editor'), child: const Text('Edit')),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({
    required this.status,
    required this.title,
    required this.meta,
  });

  final String status;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(status),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({required this.title, required this.updated});

  final String title;
  final String updated;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(updated),
        trailing: TextButton(onPressed: () {}, child: const Text('edit')),
      ),
    );
  }
}
