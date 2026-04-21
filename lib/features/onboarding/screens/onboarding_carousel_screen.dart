import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/providers/onboarding_seen_provider.dart';

class OnboardingSlide {
  final String title;
  final String description;
  final Widget showcase;

  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.showcase,
  });
}

class OnboardingCarouselScreen extends ConsumerStatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  ConsumerState<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState
    extends ConsumerState<OnboardingCarouselScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      title: 'Manage Your Store',
      description:
          'Keep track of your products, inventory, and seamless storefront operations from anywhere.',
      showcase: _StoreShowcase(),
    ),
    OnboardingSlide(
      title: 'Receive & Manage Orders',
      description:
          'Stay on top of every customer request. Process and manage all incoming orders easily.',
      showcase: _OrdersShowcase(),
    ),
    OnboardingSlide(
      title: 'Analyze Sales & Performance',
      description:
          'Gain real-time insights into your sales metrics and track your business growth effectively.',
      showcase: _AnalyticsShowcase(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(tokenStorageProvider).saveOnboardingSeen(true);
    // Router redirect requires [onboardingSeenProvider] to read true;
    // otherwise /landing is redirected back to /onboarding.
    ref.invalidate(onboardingSeenProvider);
    await ref.read(onboardingSeenProvider.future);
    if (!mounted) return;
    context.go('/landing');
  }

  Future<void> _nextPage() async {
    if (_currentIndex < _slides.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Area — brand logo anchors every slide, with Skip
            // docked in the right corner so the logo stays visually centred.
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo_with_name.png',
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (_currentIndex < _slides.length - 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _completeOnboarding(),
                          child: const Text('Skip'),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Carousel Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Feature showcase card — a preview of what the
                        // feature actually looks like in-app, matching the
                        // visual language of the landing page revenue card.
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Subtle radial glow to draw focus
                            Positioned(
                              top: 20,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey('glow_$index'),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.scale(
                                      scale: 0.8 + (0.2 * value),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.12),
                                        blurRadius: 100,
                                        spreadRadius: 30,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              key: ValueKey(index),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 24 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: slide.showcase,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          slide.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.secondary,
                            fontSize: (theme.textTheme.headlineMedium?.fontSize ?? 28) * 1.15,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls (Indicators & Button)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  // Smooth Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 8,
                        width: _currentIndex == index ? 32 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Main Action Button (Signature Gradient)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 1.0],
                        transform: const GradientRotation(2.35619), // 135 deg
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _nextPage(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: Text(
                        _currentIndex == _slides.length - 1
                            ? 'Get Started'
                            : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Showcase widgets — one per slide. Each one is a marketing visualisation of
// the feature, built in the same card style as the landing page revenue card:
// white surface, rounded corners, subtle border, soft shadow, brand accents.
// Data shown is intentionally static; these are illustrations, not live data.
// ---------------------------------------------------------------------------

/// Slide 1: two stacked product tiles plus a floating catalogue-size chip.
/// Evokes "you manage a catalogue" at a glance.
class _StoreShowcase extends StatelessWidget {
  const _StoreShowcase();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Back card — rotated and faded for depth.
          Positioned(
            top: 18,
            left: 14,
            right: 14,
            child: Transform.rotate(
              angle: -0.055,
              child: Opacity(
                opacity: 0.6,
                child: const _ProductTile(
                  title: 'Canvas Sneakers',
                  category: 'Footwear',
                  price: 'KSh 2,100',
                  icon: Icons.directions_walk_rounded,
                  stockCount: 15,
                  dense: true,
                ),
              ),
            ),
          ),
          // Front hero card.
          const Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: _ProductTile(
              title: 'Leather Tote Bag',
              category: 'Accessories',
              price: 'KSh 5,400',
              icon: Icons.shopping_bag_rounded,
              stockCount: 8,
            ),
          ),
          // Floating catalogue badge.
          const Positioned(
            top: -6,
            right: 2,
            child: _FloatingChip(
              icon: Icons.inventory_2_rounded,
              label: '124 products',
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide 2: an order card with a "New" status chip plus a stacked older
/// order behind it and a floating "3 new orders" badge.
class _OrdersShowcase extends StatefulWidget {
  const _OrdersShowcase();

  @override
  State<_OrdersShowcase> createState() => _OrdersShowcaseState();
}

class _OrdersShowcaseState extends State<_OrdersShowcase> {
  bool _showBack = false;
  bool _showFront = false;
  bool _showBadge = false;

  @override
  void initState() {
    super.initState();
    _triggerAnimations();
  }

  Future<void> _triggerAnimations() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _showBack = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _showFront = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _showBadge = true);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Older order peeking behind.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            top: _showBack ? 22 : 40,
            left: 18,
            right: 18,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _showBack ? 0.55 : 0.0,
              child: Transform.rotate(
                angle: 0.055,
                child: const _OrderCard(
                  orderId: 'DN-2839',
                  customer: 'Brian Otieno',
                  items: 2,
                  amount: 'KSh 2,150',
                  status: 'Processing',
                  statusTone: _ChipTone.neutral,
                  dense: true,
                  avatarColors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                ),
              ),
            ),
          ),
          // Fresh order in focus.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            top: _showFront ? 96 : 130,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _showFront ? 1.0 : 0.0,
              child: const _OrderCard(
                orderId: 'DN-2841',
                customer: 'Jane Mwangi',
                items: 3,
                amount: 'KSh 4,200',
                status: 'New',
                statusTone: _ChipTone.urgent,
                avatarColors: [Color(0xFFF77062), Color(0xFFFE5196)],
              ),
            ),
          ),
          // Floating notification badge.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            top: _showBadge ? -6 : 10,
            left: _showBadge ? 4 : 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showBadge ? 1.0 : 0.0,
              child: const _FloatingChip(
                icon: Icons.notifications_active_rounded,
                label: '3 new orders',
                tone: _ChipTone.primary,
                hasUnreadDot: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide 3: a weekly sales bar chart with a KPI and trend chip. Uses bars
/// (not the line used on the landing page) so the onboarding preview feels
/// distinct from the landing page visual.
class _AnalyticsShowcase extends StatefulWidget {
  const _AnalyticsShowcase();

  @override
  State<_AnalyticsShowcase> createState() => _AnalyticsShowcaseState();
}

class _AnalyticsShowcaseState extends State<_AnalyticsShowcase> {
  // Weekly sales in KSh thousands; Sat is highlighted as the peak.
  static const List<double> _targetBars = [8, 12, 9, 14, 11, 18, 16];
  static const List<String> _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _animateChart = false;
  bool _showTrend = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animateChart = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showTrend = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 260,
      child: _ShowcaseCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Sales this week',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedScale(
                  scale: _showTrend ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  child: const _StatusChip(
                    label: '+18.2%',
                    tone: _ChipTone.positive,
                    leadingIcon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 30000.0, end: _animateChart ? 92450.0 : 30000.0),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final mainPortion = (value / 1000).floor();
                final remainder = (value % 1000).toInt().toString().padLeft(3, '0');
                return Text(
                  'KSh $mainPortion,$remainder',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BarChart(
                swapAnimationDuration: const Duration(milliseconds: 1000),
                swapAnimationCurve: Curves.easeOutCubic,
                BarChartData(
                  maxY: 22,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _days.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _days[idx],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(enabled: false),
                  barGroups: [
                    for (var i = 0; i < _targetBars.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: _animateChart ? _targetBars[i] : 0,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: i == 5
                                  // Peak-day highlight: saturated brand blue.
                                  ? [AppTheme.primaryDark, AppTheme.primary]
                                  : [
                                      AppTheme.primary.withValues(alpha: 0.28),
                                      AppTheme.primary.withValues(alpha: 0.7),
                                    ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primitives shared by the showcases.
// ---------------------------------------------------------------------------

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.title,
    required this.category,
    required this.price,
    required this.icon,
    required this.stockCount,
    this.dense = false,
  });

  final String title;
  final String category;
  final String price;
  final IconData icon;
  final int stockCount;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _ShowcaseCard(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : 16,
        vertical: dense ? 12 : 16,
      ),
      child: Row(
        children: [
          Container(
            width: dense ? 44 : 56,
            height: dense ? 44 : 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.primary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(dense ? 10 : 14),
            ),
            child: Icon(
              icon,
              color: AppTheme.primary,
              size: dense ? 22 : 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: dense ? 2 : 4),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: dense ? 4 : 8),
                Row(
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: dense ? 13 : 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: '$stockCount in stock',
                      tone: _ChipTone.positive,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.customer,
    required this.items,
    required this.amount,
    required this.status,
    required this.statusTone,
    this.avatarColors,
    this.dense = false,
  });

  final String orderId;
  final String customer;
  final int items;
  final String amount;
  final String status;
  final _ChipTone statusTone;
  final List<Color>? avatarColors;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _ShowcaseCard(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 14 : 16,
        vertical: dense ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Order #$orderId',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondary,
                ),
              ),
              const Spacer(),
              _StatusChip(label: status, tone: statusTone),
            ],
          ),
          SizedBox(height: dense ? 8 : 12),
          Row(
            children: [
              Container(
                width: dense ? 28 : 32,
                height: dense ? 28 : 32,
                decoration: BoxDecoration(
                  gradient: avatarColors != null 
                    ? LinearGradient(colors: avatarColors!, begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                  color: avatarColors == null ? AppTheme.primary.withValues(alpha: 0.1) : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: dense ? 16 : 18,
                  color: avatarColors != null ? Colors.white : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$items items',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 10 : 14),
          Container(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          SizedBox(height: dense ? 8 : 12),
          Row(
            children: [
              Text(
                'Total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                amount,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: dense ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ChipTone { primary, positive, neutral, urgent }

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.tone,
    this.leadingIcon,
  });

  final String label;
  final _ChipTone tone;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = _resolveColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _resolveColors(_ChipTone tone) {
    switch (tone) {
      case _ChipTone.primary:
        return (AppTheme.primary.withValues(alpha: 0.12), AppTheme.primary);
      case _ChipTone.positive:
        return (const Color(0xFFE6F7EC), const Color(0xFF0E8A3E));
      case _ChipTone.neutral:
        return (const Color(0xFFF0EFEF), AppTheme.secondary);
      case _ChipTone.urgent:
        return (const Color(0xFFFFF2E5), const Color(0xFFFF7A00));
    }
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.icon,
    required this.label,
    this.hasUnreadDot = false,
    this.tone = _ChipTone.neutral,
  });

  final IconData icon;
  final String label;
  final bool hasUnreadDot;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (bg, fg) = _resolveIconColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: fg),
              ),
              if (hasUnreadDot)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4C4C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _resolveIconColors(_ChipTone tone) {
    switch (tone) {
      case _ChipTone.primary:
        return (AppTheme.primary.withValues(alpha: 0.14), AppTheme.primary);
      case _ChipTone.positive:
        return (const Color(0xFFE6F7EC), const Color(0xFF0E8A3E));
      case _ChipTone.neutral:
        return (AppTheme.primary.withValues(alpha: 0.12), AppTheme.primary);
      case _ChipTone.urgent:
        return (const Color(0xFFFFF2E5), const Color(0xFFFF7A00));
    }
  }
}
