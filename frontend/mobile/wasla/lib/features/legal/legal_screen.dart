import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/providers/ads_provider.dart' show externalLinkLauncherProvider;
import 'legal_provider.dart';

/// Terms of use / privacy policy, as published in app_configs.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.kind});
  final LegalKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(legalDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(kind.titleAr)),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(legalDocumentsProvider),
            child: const Text('تعذّر التحميل. إعادة المحاولة'),
          ),
        ),
        data: (all) {
          final doc = all[kind]!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('الإصدار ${doc.version}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.neutral500)),
              const SizedBox(height: 12),
              if (doc.body != null && doc.body!.trim().isNotEmpty)
                SelectableText(doc.body!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, height: 1.7)),
              if (doc.url != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.read(externalLinkLauncherProvider)(doc.url!),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('اقرأ النص الكامل'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Shown once after sign-in when the user has not accepted the current
/// versions (Google sign-in, or a newly published version).
class LegalConsentDialog extends ConsumerStatefulWidget {
  const LegalConsentDialog({super.key, required this.terms, required this.privacy});
  final LegalDocument terms;
  final LegalDocument privacy;

  @override
  ConsumerState<LegalConsentDialog> createState() => _LegalConsentDialogState();
}

class _LegalConsentDialogState extends ConsumerState<LegalConsentDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    Widget link(LegalKind kind) => TextButton(
          onPressed: () => context.push('/legal/${kind.id}'),
          child: Text(kind.titleAr),
        );
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('شروط الاستخدام وسياسة الخصوصية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('عشان تكمّل، اقرأ ووافق على الإصدار الحالي '
                '(الشروط ${widget.terms.version}، الخصوصية ${widget.privacy.version}).'),
            Wrap(children: [link(LegalKind.terms), link(LegalKind.privacy)]),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final navigator = Navigator.of(context);
                    final ok = await ref.read(legalAcceptorProvider)(widget.terms.version, widget.privacy.version);
                    if (ok) navigator.pop();
                    if (mounted) setState(() => _saving = false);
                  },
            child: const Text('أوافق'),
          ),
        ],
      ),
    );
  }
}
