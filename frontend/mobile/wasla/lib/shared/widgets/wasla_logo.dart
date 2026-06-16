import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';

// ════════════════════════════════════════════════════════════════
//  WASLA LOGO
// ════════════════════════════════════════════════════════════════
enum WaslaLogoVariant { color, white, dark }

class WaslaLogoFull extends StatelessWidget {
  const WaslaLogoFull({
    super.key,
    this.size = 44,
    this.variant = WaslaLogoVariant.color,
  });
  final double size;
  final WaslaLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final textColor = switch (variant) {
      WaslaLogoVariant.white => Colors.white,
      WaslaLogoVariant.dark  => AppColors.primary900,
      WaslaLogoVariant.color => AppColors.primary900,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WaslaLogoMark(size: size, variant: variant),
        SizedBox(width: size * 0.2),
        Text(
          AppStrings.appName,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: size * 0.75,
            color: textColor,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class WaslaLogoMark extends StatelessWidget {
  const WaslaLogoMark({super.key, this.size = 44, this.variant = WaslaLogoVariant.color});
  final double size;
  final WaslaLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final teal   = variant == WaslaLogoVariant.white ? Colors.white : AppColors.primary600;
    final gold   = variant == WaslaLogoVariant.white ? Colors.white.withOpacity(0.85) : AppColors.accent500;
    final ghost  = variant == WaslaLogoVariant.white ? Colors.white.withOpacity(0.25) : AppColors.primary200.withOpacity(0.6);
    final h = size * 0.6;

    return CustomPaint(
      size: Size(size, h),
      painter: _LogoPainter(teal: teal, gold: gold, ghost: ghost),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.teal, required this.gold, required this.ghost});
  final Color teal, gold, ghost;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Left node
    canvas.drawCircle(
      Offset(w * 0.15, h * 0.75),
      w * 0.15,
      Paint()..color = teal,
    );
    // Right node
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.75),
      w * 0.15,
      Paint()..color = teal,
    );

    final arcPaint = Paint()
      ..color = gold
      ..strokeWidth = w * 0.055
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(w * 0.29, h * 0.69)
      ..cubicTo(w * 0.38, h * 0.12, w * 0.62, h * 0.12, w * 0.71, h * 0.69);
    canvas.drawPath(path, arcPaint);

    // Ghost lower arc
    final ghostPath = Path()
      ..moveTo(w * 0.29, h * 0.81)
      ..cubicTo(w * 0.38, h * 1.08, w * 0.62, h * 1.08, w * 0.71, h * 0.81);
    canvas.drawPath(ghostPath, Paint()..color = ghost..strokeWidth = w * 0.035..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Apex dot
    canvas.drawCircle(Offset(w * 0.5, h * 0.27), w * 0.07, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ════════════════════════════════════════════════════════════════
//  PRIMARY BUTTON
// ════════════════════════════════════════════════════════════════
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.color,
    this.height = 52,
  });
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: (isLoading || isDisabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary600,
          disabledBackgroundColor: (color ?? AppColors.primary600).withOpacity(0.5),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class AccentButton extends StatelessWidget {
  const AccentButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(label: label, onPressed: onPressed, icon: icon, color: AppColors.accent500);
  }
}

// ════════════════════════════════════════════════════════════════
//  AD CARD
// ════════════════════════════════════════════════════════════════
class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.ad});
  final Map<String, dynamic> ad;

  @override
  Widget build(BuildContext context) {
    final isFeatured = ad['is_featured'] == true;
    final isUrgent   = ad['is_urgent'] == true;
    final price      = ad['price'];
    final priceType  = ad['price_type'] as String? ?? 'fixed';
    final media      = (ad['ad_media'] as List?)?.firstOrNull;
    final imageUrl   = media?['url'] as String?;
    final city       = (ad['cities'] as Map?)?['name_ar'] ?? '';

    return GestureDetector(
      onTap: () => context.push('/ad/${ad['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.adCardRadius),
          border: Border.all(
            color: isFeatured ? AppColors.accent500 : AppColors.neutral200,
            width: isFeatured ? 2 : 1,
          ),
          boxShadow: isFeatured
              ? [BoxShadow(color: AppColors.accent500.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image ────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.adCardRadius)),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: AppSizes.adCardImageHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _ImagePlaceholder(),
                          errorWidget: (_, __, ___) => _ImagePlaceholder(),
                        )
                      : _ImagePlaceholder(),
                ),
                // Badges
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (isFeatured) _Badge(label: '⭐ مميز', bg: AppColors.accent500),
                      if (isUrgent)   ...[const SizedBox(width: 4), _Badge(label: '🔴 عاجل', bg: AppColors.error)],
                    ],
                  ),
                ),
              ],
            ),

            // ── Info ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad['title'] ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _PriceWidget(price: price, priceType: priceType),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: AppColors.neutral400),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          city,
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.adCardImageHeight,
      color: AppColors.neutral100,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: AppColors.neutral300),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg});
  final String label;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PriceWidget extends StatelessWidget {
  const _PriceWidget({required this.price, required this.priceType});
  final dynamic price;
  final String priceType;

  @override
  Widget build(BuildContext context) {
    if (priceType == 'free') {
      return const Text(
        AppStrings.free,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: AppColors.success,
        ),
      );
    }
    if (priceType == 'negotiable' || price == null) {
      return const Text(
        AppStrings.negotiable,
        style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500, fontSize: 13),
      );
    }

    final suffix = switch (priceType) {
      'per_hour'  => ' / ${AppStrings.perHour}',
      'per_month' => ' / ${AppStrings.perMonth}',
      _           => '',
    };

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Cairo', height: 1),
        children: [
          TextSpan(
            text: '${price.toStringAsFixed(0)} ',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary600,
            ),
          ),
          TextSpan(
            text: '${AppStrings.egp}$suffix',
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SHIMMER LOADING
// ════════════════════════════════════════════════════════════════
class AdCardShimmer extends StatelessWidget {
  const AdCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral100,
      highlightColor: AppColors.neutral50,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.adCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: AppSizes.adCardImageHeight, color: AppColors.neutral200,
              decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.adCardRadius)))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Container(height: 14, color: AppColors.neutral200),
                const SizedBox(height: 6),
                Container(height: 14, width: 100, color: AppColors.neutral200),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ════════════════════════════════════════════════════════════════
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 72, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SECTION HEADER
// ════════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.actionLabel});
  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (action != null)
            TextButton(
              onPressed: action,
              child: Text(actionLabel ?? AppStrings.viewAll),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  VERIFIED BADGE
// ════════════════════════════════════════════════════════════════
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.6, vertical: size * 0.2),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.success, size: size),
          SizedBox(width: size * 0.3),
          Text(
            AppStrings.verified,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: size * 0.85,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
