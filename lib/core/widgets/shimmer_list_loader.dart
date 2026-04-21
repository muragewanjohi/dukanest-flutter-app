import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';

class ShimmerListLoader extends StatelessWidget {
  const ShimmerListLoader({
    super.key,
    this.itemCount = 5,
    this.height = 80,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.baseColor,
    this.highlightColor,
  });

  final int itemCount;
  final double height;
  final EdgeInsetsGeometry margin;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Shimmer.fromColors(
      baseColor: baseColor ?? theme.colorScheme.surfaceContainerLow,
      highlightColor: highlightColor ?? theme.colorScheme.surface,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          margin: margin,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
