import 'package:flutter/material.dart';

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    required this.title,
    this.description,
    super.key,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
