import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/image_utils.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  WASLA LOGO
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size * 0.86,
      fit: BoxFit.contain,
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  PRIMARY BUTTON
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
          disabledBackgroundColor: (color ?? AppColors.primary600).withValues(alpha: 0.5),
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  AD CARD
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

    // In a grid cell or a fixed-height row the card has a bounded height: the
    // photo takes what the text leaves, so long titles never overflow. In a
    // list the photo keeps its fixed height.
    return LayoutBuilder(builder: (context, constraints) {
    final bounded = constraints.hasBoundedHeight;
    Widget image(Widget child) => bounded ? Expanded(child: child) : child;
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
              ? [BoxShadow(color: AppColors.accent500.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // â”€â”€ Image â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            image(Stack(
              fit: bounded ? StackFit.expand : StackFit.loose,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.adCardRadius)),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ImageUtils.thumbnail(imageUrl),
                          height: bounded ? null : AppSizes.adCardImageHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _ImagePlaceholder(fill: bounded),
                          errorWidget: (_, __, ___) => _ImagePlaceholder(fill: bounded),
                        )
                      : _ImagePlaceholder(fill: bounded),
                ),
                // Badges
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (isFeatured) _Badge(label: '⭐ ${'featured'.tr()}', bg: AppColors.accent500),
                      if (isUrgent)   ...[const SizedBox(width: 4), _Badge(label: '🔴 ${'urgent'.tr()}', bg: AppColors.error)],
                    ],
                  ),
                ),
              ],
            )),

            // â”€â”€ Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    });
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.fill = false});
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: fill ? null : AppSizes.adCardImageHeight,
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
      return Text(AppStrings.free,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: AppColors.success,
        ),
      );
    }
    if (priceType == 'negotiable' || price == null) {
      return Text(AppStrings.negotiable,
        style: const TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500, fontSize: 13),
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  SHIMMER LOADING
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
            Container(
              height: AppSizes.adCardImageHeight,
              decoration: const BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.adCardRadius)),
              ),
            ),
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  EMPTY STATE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  SECTION HEADER
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  VERIFIED BADGE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
