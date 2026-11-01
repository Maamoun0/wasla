import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/data/repositories/ads_repository.dart';
import 'package:wasla/data/repositories/notifications_repository.dart';
import 'package:wasla/data/repositories/payments_repository.dart';
import 'package:wasla/data/repositories/saved_repository.dart';

/// A client whose HTTP calls are recorded and answered with [reply].
(SupabaseClient, List<http.Request>) fakeClient(Object? Function(http.Request) reply) {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:1',
    'test-key',
    httpClient: MockClient((req) async {
      requests.add(req);
      return http.Response(jsonEncode(reply(req)), 200, headers: {'content-type': 'application/json'}, request: req);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (client, requests);
}

void main() {
  test('searchAds calls the search_ads RPC with the filters and the select list', () async {
    final (client, requests) = fakeClient((_) => [
          {'id': 'a1', 'title': 'x'}
        ]);
    final ads = await AdsRepository(client).searchAds({'p_query': 'شقة', 'p_limit': 20}, 'id, title');

    expect(ads.single['id'], 'a1');
    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/rest/v1/rpc/search_ads');
    expect(req.url.queryParameters['select'], 'id,title');
    expect(jsonDecode(req.body), {'p_query': 'شقة', 'p_limit': 20});
  });

  test('featuredAds reads active featured ads, newest first, 10 at most', () async {
    final (client, requests) = fakeClient((_) => const []);
    await AdsRepository(client).featuredAds();

    final q = requests.single.url.queryParameters;
    expect(requests.single.url.path, '/rest/v1/ads');
    expect([q['status'], q['is_featured'], q['order'], q['limit']],
        ['eq.active', 'eq.true', 'published_at.desc.nullslast', '10']);
  });

  test('setFavorite inserts or deletes the (user, ad) row', () async {
    final (client, requests) = fakeClient((_) => null);
    final repo = AdsRepository(client);

    await repo.setFavorite(userId: 'u1', adId: 'a1', favorite: true);
    await repo.setFavorite(userId: 'u1', adId: 'a1', favorite: false);

    expect(requests.map((r) => r.method), ['POST', 'DELETE']);
    expect(jsonDecode(requests[0].body), {'user_id': 'u1', 'ad_id': 'a1'});
    expect(requests[1].url.queryParameters, containsPair('user_id', 'eq.u1'));
    expect(requests[1].url.queryParameters, containsPair('ad_id', 'eq.a1'));
  });

  test('saved searches are toggled and deleted by id', () async {
    final (client, requests) = fakeClient((_) => null);
    final repo = SavedRepository(client);

    await repo.setSavedSearchActive('s1', false);
    await repo.deleteSavedSearch('s1');

    expect(requests.map((r) => '${r.method} ${r.url.path}'),
        ['PATCH /rest/v1/saved_searches', 'DELETE /rest/v1/saved_searches']);
    expect(jsonDecode(requests[0].body), {'is_active': false});
    expect(requests.every((r) => r.url.queryParameters['id'] == 'eq.s1'), isTrue);
  });

  test('markRead sends the ids, or null to mark all', () async {
    final (client, requests) = fakeClient((_) => null);
    final repo = NotificationsRepository(client);

    await repo.markRead(['n1']);
    await repo.markRead(null);

    expect(requests.map((r) => jsonDecode(r.body)), [
      {'p_ids': ['n1']},
      {'p_ids': null},
    ]);
    expect(requests.first.url.path, '/rest/v1/rpc/mark_notifications_read');
  });

  test('createPayment calls create-payment and returns its checkout', () async {
    final (client, requests) = fakeClient((_) => {'iframe_url': 'https://pay.test/1'});
    final checkout = await PaymentsRepository(client).createPayment({'package_id': 'p1'});

    expect(checkout, {'iframe_url': 'https://pay.test/1'});
    expect(requests.single.url.path, '/functions/v1/create-payment');
    expect(jsonDecode(requests.single.body), {'package_id': 'p1'});
  });
}
