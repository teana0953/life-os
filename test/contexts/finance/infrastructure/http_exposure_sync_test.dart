import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/finance/application/networth_use_cases.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exposure_http_server.dart';
import '../finance_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'independent HTTP clients save, refresh, clear and recreate without importing local preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'networth.exposure.v1:a:asset': 3,
      });
      final prefs = await SharedPreferences.getInstance();
      final server = ExposureHttpServer();
      final repoA = server.client();
      final repoB = server.client();
      expect(identical(repoA.client, repoB.client), isFalse);
      final a = testNetWorthController(repoA);
      final b = testNetWorthController(repoB);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.loadForUser('a');
      await b.loadForUser('a');
      expect(server.requests, isEmpty);
      await a.load('a-device-1', '2026-07');
      await b.load('a-device-2', '2026-07');
      expect(a.accounts.first.exposureFactor, isNull);
      expect(b.accounts.first.exposureFactor, isNull);
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(
        await a.saveExposureFactor(
          'asset',
          ExposureFactor.leveraged2,
          session: a.exposureSession,
          idToken: () async => 'a-device-1',
        ),
        isTrue,
      );
      expect(b.accounts.first.exposureFactor, isNull);
      await b.load('a-device-2', '2026-07');
      expect(b.exposureFactors['asset'], ExposureFactor.leveraged2);
      expect(b.exposure!.totalExposure, 300);
      expect(
        await b.saveExposureFactor(
          'asset',
          null,
          session: b.exposureSession,
          idToken: () async => 'a-device-2',
        ),
        isTrue,
      );
      await a.load('a-device-1', '2026-07');
      expect(a.accounts.first.exposureFactor, isNull);
      expect(a.exposure!.status, ExposureStatus.unclassified);
      final recreated = testNetWorthController(server.client());
      addTearDown(recreated.dispose);
      await recreated.loadForUser('a');
      await recreated.load('a-device-1', '2026-08');
      expect(recreated.accounts.first.exposureFactor, isNull);
      expect(prefs.getInt('networth.exposure.v1:a:asset'), 3);
      expect(
        server.requests.where(
          (r) => r.url.path.endsWith('/accounts') && r.method == 'GET',
        ),
        hasLength(5),
      );
      expect(server.requests.where((r) => r.method == 'PUT'), hasLength(2));
      expect(
        server.requests.every((r) => r.headers['Authorization'] != 'Bearer a'),
        isTrue,
      );
    },
  );

  for (final factor in <ExposureFactor?>[null, ...ExposureFactor.values]) {
    test(
      'HTTP round trips $factor and unrelated updates omit exposure',
      () async {
        final server = ExposureHttpServer();
        final repo = server.client();
        final updated = await UpdateNetWorthAccount(repo)(
          'a-device-1',
          'asset',
          exposure: (value: factor),
        );
        expect(updated.exposureFactor, factor);
        expect(jsonDecode(server.requests.last.body), {
          'exposure_factor': factor?.multiplier,
        });
        expect(
          server.requests.last.headers['Authorization'],
          'Bearer a-device-1',
        );
        await repo.updateNetWorthAccount(
          'a-device-1',
          'asset',
          name: 'Renamed',
          sortOrder: 7,
          archived: true,
        );
        expect(jsonDecode(server.requests.last.body), {
          'name': 'Renamed',
          'sort_order': 7,
          'archived': true,
        });
        final fromOtherClient = (await server.client().listNetWorthAccounts(
          'a-device-2',
        )).first;
        expect(fromOtherClient.exposureFactor, factor);
        expect(fromOtherClient.name, 'Renamed');
        expect(fromOtherClient.archived, isTrue);
        expect(fromOtherClient.sortOrder, 7);
      },
    );
  }

  test(
    'archived assets remain editable and liability actions do not dispatch',
    () async {
      final server = ExposureHttpServer();
      final controller = testNetWorthController(server.client());
      await controller.load('a-device-1', '2026-07');
      final session = controller.exposureSession;
      expect(
        await controller.saveExposureFactor(
          'archived',
          ExposureFactor.leveraged3,
          session: session,
          idToken: () async => 'a-device-1',
        ),
        isTrue,
      );
      final requests = server.requests.length;
      expect(
        await controller.saveExposureFactor(
          'debt',
          ExposureFactor.cash,
          session: session,
          idToken: () async => 'a-device-1',
        ),
        isFalse,
      );
      expect(server.requests, hasLength(requests));
      expect(controller.exposureFactors['archived'], ExposureFactor.leveraged3);
    },
  );

  for (final invalid in ['2', true, 1.5, -1, 4, {}, []]) {
    test(
      'invalid returned exposure $invalid fails account read and update decoding',
      () async {
        final account = {
          'id': 'asset',
          'kind': 'asset',
          'name': 'Asset',
          'sort_order': 0,
          'archived': false,
          'exposure_factor': invalid,
        };
        final repo = HttpFinanceRepository(
          baseUrl: 'https://exposure.test',
          client: MockClient(
            (r) async => http.Response(
              jsonEncode(
                r.method == 'GET'
                    ? {
                        'accounts': [account],
                      }
                    : account,
              ),
              200,
            ),
          ),
        );
        await expectLater(
          repo.listNetWorthAccounts('token'),
          throwsA(isA<FinanceFetchFailure>()),
        );
        await expectLater(
          repo.updateNetWorthAccount(
            'token',
            'asset',
            exposure: (value: ExposureFactor.cash),
          ),
          throwsA(isA<FinanceFetchFailure>()),
        );
      },
    );
  }

  test('old server without exposure returns unknown', () async {
    final repo = HttpFinanceRepository(
      baseUrl: 'https://exposure.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'accounts': [
              {
                'id': 'asset',
                'kind': 'asset',
                'name': 'Asset',
                'sort_order': 0,
                'archived': false,
              },
            ],
          }),
          200,
        ),
      ),
    );
    expect(
      (await repo.listNetWorthAccounts('token')).single.exposureFactor,
      isNull,
    );
  });

  for (final reauth in [false, true]) {
    test(
      'HTTP ${reauth ? '401' : 'network'} save and reload failures are explicit and preserve confirmed factors',
      () async {
        final server = ExposureHttpServer();
        final controller = testNetWorthController(server.client());
        await controller.load('a-device-1', '2026-07');
        expect(
          await controller.saveExposureFactor(
            'asset',
            ExposureFactor.cash,
            session: controller.exposureSession,
            idToken: () async => 'a-device-1',
          ),
          isTrue,
        );
        server.offline = !reauth;
        server.failureStatus = reauth ? 401 : null;
        expect(
          await controller.saveExposureFactor(
            'asset',
            ExposureFactor.leveraged2,
            session: controller.exposureSession,
            idToken: () async => 'a-device-1',
          ),
          isFalse,
        );
        expect(controller.exposureSaveFailed, isTrue);
        expect(controller.exposureFactors['asset'], ExposureFactor.cash);
        if (reauth) expect(controller.status, FinanceStatus.needsReauth);
        await controller.load('a-device-1', '2026-07');
        expect(
          controller.status,
          reauth ? FinanceStatus.needsReauth : FinanceStatus.error,
        );
        expect(controller.exposureFactors['asset'], ExposureFactor.cash);
        expect(controller.reloadFailed || reauth, isTrue);
      },
    );
  }

  for (final requested in <ExposureFactor?>[null, ExposureFactor.leveraged2]) {
    for (final missing in [false, true]) {
      test('exposure PUT rejects ${missing ? 'legacy missing' : 'mismatched'} acknowledgement for $requested', () async {
        final account = <String, dynamic>{
          'id': 'asset', 'kind': 'asset', 'name': 'Asset', 'sort_order': 0, 'archived': false,
          'exposure_factor': 0,
        };
        final repo = HttpFinanceRepository(baseUrl: 'https://exposure.test', client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path.endsWith('/accounts')) {
            return http.Response(jsonEncode({'accounts': [account]}), 200);
          }
          if (request.method == 'PUT') {
            return http.Response(jsonEncode({for (final entry in account.entries) if (!missing || entry.key != 'exposure_factor') entry.key: entry.value}), 200);
          }
          return ExposureHttpServer().handle(http.Request('GET', request.url)..headers['Authorization'] = 'Bearer a-device-1');
        }));
        await expectLater(repo.updateNetWorthAccount('token', 'asset', exposure: (value: requested)), throwsA(isA<FinanceFetchFailure>()));
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');
        expect(await controller.saveExposureFactor('asset', requested,
          session: controller.exposureSession, idToken: () async => 'token'), isFalse);
        expect(controller.exposureSaveFailed, isTrue);
        expect(controller.exposureFactors['asset'], ExposureFactor.cash);
      });
    }
  }
}
