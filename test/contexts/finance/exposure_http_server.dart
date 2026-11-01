import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';

class ExposureHttpServer {
  final List<http.Request> requests = [];
  int? failureStatus;
  bool offline = false;
  final Map<String, List<Map<String, dynamic>>> users = {
    for (final uid in ['a', 'b'])
      uid: [
        {
          'id': 'asset',
          'kind': 'asset',
          'name': 'Investment',
          'sort_order': 0,
          'archived': false,
          'exposure_factor': null,
        },
        {
          'id': 'archived',
          'kind': 'asset',
          'name': 'Property',
          'sort_order': 1,
          'archived': true,
          'exposure_factor': 1,
        },
        {
          'id': 'debt',
          'kind': 'liability',
          'name': 'Debt',
          'sort_order': 0,
          'archived': false,
          'exposure_factor': null,
        },
      ],
  };

  HttpFinanceRepository client() => HttpFinanceRepository(
    baseUrl: 'https://exposure.test',
    client: MockClient(handle),
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline');
    if (failureStatus case final status?) return http.Response('{}', status);
    final uid = switch (request.headers['Authorization']) {
      'Bearer a-device-1' || 'Bearer a-device-2' => 'a',
      'Bearer b-device' => 'b',
      _ => null,
    };
    if (uid == null) return http.Response('{}', 401);
    final accounts = users[uid]!;
    final path = request.url.path;
    if (path.endsWith('/accounts') && request.method == 'GET') {
      return _json({'accounts': accounts});
    }
    if (path.endsWith('/accounts/order')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final ids = body['ids'] as List;
      for (var i = 0; i < ids.length; i++) {
        accounts.firstWhere((a) => a['id'] == ids[i])['sort_order'] = i;
      }
      return _json({});
    }
    if (path.contains('/accounts/') && request.method == 'PUT') {
      final id = request.url.pathSegments.last;
      final index = accounts.indexWhere((a) => a['id'] == id);
      if (index < 0) return http.Response('{}', 404);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      accounts[index] = {...accounts[index], ...body};
      return _json(accounts[index]);
    }
    if (path.endsWith('/trend')) return _json({'points': []});
    if (path.endsWith('/networth')) {
      return _json({
        'month': request.url.queryParameters['month'],
        'accounts': [
          for (final account in accounts)
            {
              'account_id': account['id'],
              'kind': account['kind'],
              'name': account['name'],
              'value': account['kind'] == 'asset' ? 100 : 20,
            },
        ],
        'total_asset': 200,
        'total_liability': 20,
        'net_worth': 180,
        'prev_net_worth': null,
        'growth_rate': null,
      });
    }
    return http.Response('{}', 404);
  }

  http.Response _json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
