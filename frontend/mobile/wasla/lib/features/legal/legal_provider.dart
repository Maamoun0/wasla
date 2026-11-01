import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/config_repository.dart';
import '../auth/providers/auth_provider.dart';

/// 'terms' or 'privacy'.
enum LegalKind {
  terms('terms', 'شروط الاستخدام'),
  privacy('privacy', 'سياسة الخصوصية');

  const LegalKind(this.id, this.titleAr);
  final String id;
  final String titleAr;

  static LegalKind? fromId(String? id) => LegalKind.values.where((k) => k.id == id).firstOrNull;
}

/// One published document (app_configs 'legal_<kind>'): text and/or a link,
/// with the version the user's acceptance is recorded against.
class LegalDocument {
  const LegalDocument({required this.kind, required this.version, this.body, this.url});

  final LegalKind kind;
  final int version;
  final String? body;
  final Uri? url;

  factory LegalDocument.fromConfig(LegalKind kind, Object? value) {
    final map = value is Map ? value : const {};
    final rawUrl = map['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    return LegalDocument(
      kind: kind,
      version: (map['version'] as num?)?.toInt() ?? 0,
      body: map['body'] is String ? map['body'] as String : null,
      // Only web links: never a scheme that could run something else.
      url: (url != null && (url.scheme == 'https' || url.scheme == 'http')) ? url : null,
    );
  }
}

final legalDocumentsProvider = FutureProvider<Map<LegalKind, LegalDocument>>((ref) async {
  final rows = await ref.watch(configRepositoryProvider).configs(['legal_terms', 'legal_privacy']);
  final byKey = {for (final r in rows) r['key'] as String: r['value']};
  return {for (final k in LegalKind.values) k: LegalDocument.fromConfig(k, byKey['legal_${k.id}'])};
});

/// Whether the signed-in user accepted the current versions (legal_status).
final legalStatusProvider = FutureProvider.autoDispose<bool?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final res = await ref.watch(configRepositoryProvider).legalStatus();
  return res is Map ? res['accepted'] == true : null;
});

/// Records acceptance of the versions the user was shown. Returns false when
/// a newer version was published meanwhile (the user must see it first).
Future<bool> acceptLegalDocuments(Ref ref, {required int termsVersion, required int privacyVersion}) async {
  final res = await ref
      .read(configRepositoryProvider)
      .acceptLegalDocuments(termsVersion: termsVersion, privacyVersion: privacyVersion);
  ref.invalidate(legalStatusProvider);
  if (res is Map && res['success'] == true) return true;
  ref.invalidate(legalDocumentsProvider);
  return false;
}

/// [acceptLegalDocuments] for widgets.
final legalAcceptorProvider = Provider<Future<bool> Function(int termsVersion, int privacyVersion)>(
  (ref) => (t, p) => acceptLegalDocuments(ref, termsVersion: t, privacyVersion: p),
);

/// Accepts whatever versions are current now (the user ticked the box on
/// those just before signing in).
final acceptCurrentLegalProvider = Provider<Future<bool> Function()>((ref) => () async {
      final docs = await ref.read(legalDocumentsProvider.future);
      return acceptLegalDocuments(ref,
          termsVersion: docs[LegalKind.terms]!.version, privacyVersion: docs[LegalKind.privacy]!.version);
    });
