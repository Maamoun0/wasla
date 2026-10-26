import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/providers/ads_provider.dart';
import '../../../shared/widgets/wasla_logo.dart' show EmptyState;
import '../../../shared/widgets/trust_badge.dart';
import '../../../features/auth/providers/auth_provider.dart';

class AdDetailScreen extends ConsumerStatefulWidget {
  const AdDetailScreen({super.key, required this.adId});
  final String adId;

  @override
  ConsumerState<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends ConsumerState<AdDetailScreen> {
  final _pageController = PageController();
  int _currentPhoto    = 0;
  bool _isFavorited    = false;
  bool _descExpanded   = false;

  @override
  void initState() {
    super.initState();
    _checkFavorited();
  }

  Future<void> _checkFavorited() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final client = ref.read(supabaseClientProvider);
    final res = await client
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('ad_id', widget.adId)
        .maybeSingle();
    if (mounted) setState(() => _isFavorited = res != null);
  }

  Future<void> _toggleFavorite() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) { context.push(AppRoutes.auth); return; }
    final client = ref.read(supabaseClientProvider);
    await toggleFavorite(
      client: client,
      adId: widget.adId,
      userId: uid,
      isFavorited: _isFavorited,
    );
    setState(() => _isFavorited = !_isFavorited);
  }

  Future<void> _contact(Map<String, dynamic> ad, String type) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) { context.push(AppRoutes.auth); return; }
    final client = ref.read(supabaseClientProvider);

    void notify(String msg) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    final SellerPhoneResult result;
    try {
      result = await revealSellerPhone(client: client, adId: widget.adId, contactType: type);
    } catch (_) {
      notify('تعذّر الوصول لبيانات التواصل. حاول مرة أخرى.');
      return;
    }

    final String phone;
    switch (result) {
      case SellerPhoneRevealed(phone: final p):
        phone = p;
      case SellerPhoneRateLimited(retryAfter: final wait):
        notify('وصلت للحد المسموح لعرض أرقام البائعين. حاول بعد ${(wait.inMinutes + 1)} دقيقة.');
        return;
      case SellerPhoneUnavailable():
        notify('هذا الإعلان غير متاح للتواصل حالياً.');
        return;
    }

    Uri uri;
    switch (type) {
      case 'whatsapp':
        uri = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
      case 'phone':
        uri = Uri.parse('tel:$phone');
      default:
        return;
    }
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _report(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSheet(adId: widget.adId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adAsync = ref.watch(adDetailProvider(widget.adId));

    return adAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: EmptyState(title: 'خطأ في تحميل الإعلان', subtitle: e.toString())),
      data: (ad) {
        if (ad == null) return const Scaffold(body: EmptyState(title: 'الإعلان غير موجود'));

        final media      = (ad['ad_media'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final user       = (ad['users'] as Map?)?.cast<String, dynamic>() ?? {};
        final cityName   = (ad['cities'] as Map?)?['name_ar'] as String? ?? '';
        final distName   = (ad['districts'] as Map?)?['name_ar'] as String? ?? '';
        final fields     = (ad['ad_fields'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final isFeatured = ad['is_featured'] == true;
        final isUrgent   = ad['is_urgent'] == true;
        final createdAt  = ad['created_at'] != null
            ? DateTime.tryParse(ad['created_at'] as String)
            : null;

        // Sort media: primary first
        media.sort((a, b) => (b['is_primary'] == true ? 1 : 0) - (a['is_primary'] == true ? 1 : 0));

        return Scaffold(
          backgroundColor: AppColors.neutral50,
          body: CustomScrollView(
            slivers: [
              // ── Photo Sliver ────────────────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.neutral900,
                leading: _CircleNavBtn(icon: Icons.arrow_back_ios_rounded, onTap: () => context.pop()),
                actions: [
                  _CircleNavBtn(
                    icon: _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFavorited ? AppColors.error : null,
                    onTap: _toggleFavorite,
                  ),
                  _CircleNavBtn(icon: Icons.more_vert_rounded, onTap: () => _report(context)),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      media.isEmpty
                          ? Container(color: AppColors.neutral200, child: const Center(child: Icon(Icons.image_outlined, size: 80, color: AppColors.neutral300)))
                          : PageView.builder(
                              controller: _pageController,
                              itemCount: media.length,
                              onPageChanged: (i) => setState(() => _currentPhoto = i),
                              itemBuilder: (_, i) => CachedNetworkImage(
                                imageUrl: media[i]['url'] as String,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: AppColors.neutral200),
                              ),
                            ),
                      if (media.length > 1)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(media.length, (i) => AnimatedContainer(
                              duration: AppDurations.fast,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _currentPhoto ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _currentPhoto ? AppColors.white : AppColors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                          ),
                        ),
                      if (isFeatured) const Positioned(top: 12, right: 16,
                        child: _Badge(label: '⭐ مميز', bg: AppColors.accent500)),
                      if (isUrgent) Positioned(top: 12, right: isFeatured ? 90 : 16,
                        child: const _Badge(label: '🔴 عاجل', bg: AppColors.error)),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title & Price ──────────────────────
                      Text(ad['title'] as String? ?? '', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      _PriceRow(ad: ad),
                      const SizedBox(height: 12),

                      // ── Location & Time ────────────────────
                      Row(children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: AppColors.neutral400),
                        const SizedBox(width: 4),
                        Text(
                          [cityName, if (distName.isNotEmpty) distName].join(' — '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.neutral400),
                        const SizedBox(width: 4),
                        Text(
                          createdAt != null ? timeago.format(createdAt, locale: 'ar') : '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ]),
                      const SizedBox(height: 20),
                      const Divider(),

                      // ── Dynamic Fields ─────────────────────
                      if (fields.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DynamicFieldsGrid(fields: fields),
                        const SizedBox(height: 16),
                        const Divider(),
                      ],

                      // ── Description ────────────────────────
                      const SizedBox(height: 16),
                      Text('التفاصيل', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _descExpanded = !_descExpanded),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ad['description'] as String? ?? '',
                              style: Theme.of(context).textTheme.bodyLarge,
                              maxLines: _descExpanded ? null : 4,
                              overflow: _descExpanded ? null : TextOverflow.ellipsis,
                            ),
                            TextButton(
                              onPressed: () => setState(() => _descExpanded = !_descExpanded),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: Text(_descExpanded ? 'أقل' : 'عرض المزيد'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),

                      // ── Seller Card ────────────────────────
                      const SizedBox(height: 16),
                      _SellerCard(user: user, onTap: () {
                        final sellerId = ad['user_id'] as String?;
                        if (sellerId != null) context.push('/seller/$sellerId');
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom Action Bar ──────────────────────────────
          bottomNavigationBar: _BottomActionBar(
            onCall:      () => _contact(ad, 'phone'),
            onWhatsapp:  () => _contact(ad, 'whatsapp'),
            onFavorite:  _toggleFavorite,
            isFavorited: _isFavorited,
          ),
        );
      },
    );
  }
}

class _CircleNavBtn extends StatelessWidget {
  const _CircleNavBtn({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg});
  final String label; final Color bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.ad});
  final Map<String, dynamic> ad;

  @override
  Widget build(BuildContext context) {
    final priceType = ad['price_type'] as String? ?? 'fixed';
    final price     = ad['price'];
    final adType    = ad['ad_type'] as String? ?? 'offering';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: adType == 'offering' ? AppColors.primary50 : AppColors.accent50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            adType == 'offering' ? AppStrings.offering : AppStrings.seeking,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700,
              color: adType == 'offering' ? AppColors.primary600 : AppColors.accent600),
          ),
        ),
        const SizedBox(width: 10),
        if (priceType == 'free')
          Text(AppStrings.free, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.success))
        else if (priceType == 'negotiable' || price == null)
          Text(AppStrings.negotiable, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500))
        else
          RichText(text: TextSpan(style: const TextStyle(fontFamily: 'Cairo'), children: [
            TextSpan(text: '${(price as num).toStringAsFixed(0)} ',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary600)),
            TextSpan(text: AppStrings.egp, style: const TextStyle(fontSize: 13, color: AppColors.neutral500)),
          ])),
      ],
    );
  }
}

class _DynamicFieldsGrid extends StatelessWidget {
  const _DynamicFieldsGrid({required this.fields});
  final List<Map<String, dynamic>> fields;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: fields.map((f) {
        final label = (f['category_fields'] as Map?)?['label_ar'] as String? ?? '';
        final value = f['value_text'] ?? f['value_number']?.toString() ?? '';
        if (value.toString().isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value.toString(), style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name       = user['full_name'] as String? ?? 'مستخدم';
    final avatar     = user['avatar_url'] as String?;
    final score      = (user['trust_score'] as num?)?.toDouble() ?? 0;
    final isVerified = user['is_id_verified'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary50,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null ? const Icon(Icons.person_rounded, color: AppColors.primary200, size: 26) : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name, 
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  TrustBadge(trustScore: score, isVerified: isVerified),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.onCall, required this.onWhatsapp, required this.onFavorite, required this.isFavorited});
  final VoidCallback onCall, onWhatsapp, onFavorite;
  final bool isFavorited;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.neutral200)),
        boxShadow: [BoxShadow(color: AppColors.neutral900.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // Favorite
          _ActionBtn(icon: isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorited ? AppColors.error : AppColors.neutral400, onTap: onFavorite),
          const SizedBox(width: 10),
          // WhatsApp
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onWhatsapp,
                icon: const Text('💬', style: TextStyle(fontSize: 16)),
                label: const Text('واتساب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Call
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('اتصال'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon; final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Icon(icon, color: color, size: 22),
    ),
  );
}

class _ReportSheet extends ConsumerWidget {
  const _ReportSheet({required this.adId});
  final String adId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reasons = [
      ('fraud', 'احتيال أو نصب'),
      ('duplicate', 'إعلان مكرر'),
      ('inappropriate', 'محتوى غير لائق'),
      ('wrong_category', 'قسم خاطئ'),
      ('spam', 'سبام'),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.neutral200, borderRadius: BorderRadius.circular(2)))),
          Text('الإبلاغ عن الإعلان', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...reasons.map((r) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r.$2, style: Theme.of(context).textTheme.bodyLarge),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.neutral400),
            onTap: () async {
              final uid = ref.read(currentUserIdProvider);
              if (uid == null) { Navigator.pop(context); return; }
              await ref.read(supabaseClientProvider).from('reports').insert({
                'reporter_id': uid, 'target_type': 'ad', 'target_id': adId, 'reason': r.$1,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال البلاغ. شكراً لمساعدتك!', style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                );
              }
            },
          )),
        ],
      ),
    );
  }
}
