import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';
import 'package:life_os/contexts/split/infrastructure/http_split_repository.dart';

Map<String, dynamic> _groupJson({List<Map<String, dynamic>>? members}) => {
  'id': 'g1',
  'name': 'Trip',
  'created_by_user_id': 'u1',
  'archived_at': null,
  if (members != null) 'members': members,
};

Map<String, dynamic> _memberJson() => {
  'group_id': 'g1',
  'user_id': 'u2',
  'display_name': 'Bo',
  'joined_at': '2026-08-01T00:00:00.000Z',
};

Map<String, dynamic> _expenseJson() => {
  'id': 'e1',
  'group_id': 'g1',
  'payer_user_id': 'u1',
  'payer_display_name': 'Alex',
  'created_by_user_id': 'u1',
  'amount': 900,
  'currency': 'TWD',
  'description': 'Dinner',
  'day': '2026-08-02',
  'split_mode': 'equal',
  'shares': <Map<String, dynamic>>[],
  'created_at': '2026-08-02T00:00:00.000Z',
  'updated_at': '2026-08-02T00:00:00.000Z',
};

Map<String, dynamic> _balancesJson() => {
  'balances': [
    {
      'user_id': 'u2',
      'display_name': 'Bo',
      'balances': [
        {'currency': 'TWD', 'amount': 500},
      ],
    },
  ],
};

void main() {
  group('HttpSplitRepository', () {
    test('listGroups GETs {baseUrl}/api/split/groups with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'groups': [
              _groupJson(members: [_memberJson()]),
            ],
          }),
          200,
        );
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final groups = await repository.listGroups('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/split/groups'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(groups.single.members!.single.displayName, 'Bo');
    });

    test('createGroup POSTs name to /api/split/groups and parses a group with no members', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_groupJson()), 201);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final group = await repository.createGroup('token-123', 'Trip');

      expect(capturedUri, Uri.parse('https://example.test/api/split/groups'));
      expect(capturedMethod, 'POST');
      expect(capturedBody, {'name': 'Trip'});
      expect(group.id, 'g1');
      expect(group.members, isNull);
    });

    test('getGroup GETs /api/split/groups/:id and parses group+members as sibling keys', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'group': _groupJson(), 'members': [_memberJson()]}),
          200,
        );
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final result = await repository.getGroup('token-123', 'g1');

      expect(capturedUri, Uri.parse('https://example.test/api/split/groups/g1'));
      expect(result.group.id, 'g1');
      expect(result.group.members, isNull);
      expect(result.members.single.displayName, 'Bo');
    });

    test('addGroupMember POSTs user_id to /api/split/groups/:id/members', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_memberJson()), 201);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final member = await repository.addGroupMember('token-123', 'g1', 'u2');

      expect(capturedUri, Uri.parse('https://example.test/api/split/groups/g1/members'));
      expect(capturedMethod, 'POST');
      expect(capturedBody, {'user_id': 'u2'});
      expect(member.userId, 'u2');
    });

    test('archiveGroup DELETEs to /api/split/groups/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(jsonEncode({'archived': true}), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      await repository.archiveGroup('token-123', 'g1');

      expect(capturedUri, Uri.parse('https://example.test/api/split/groups/g1'));
      expect(capturedMethod, 'DELETE');
    });

    test('getGroupBalances GETs /api/split/groups/:id/balances', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_balancesJson()), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final balances = await repository.getGroupBalances('token-123', 'g1');

      expect(capturedUri, Uri.parse('https://example.test/api/split/groups/g1/balances'));
      expect(balances.single.displayName, 'Bo');
    });

    test('listExpenses GETs /api/split/expenses with no query params when unfiltered', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'expenses': [_expenseJson()],
          }),
          200,
        );
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final expenses = await repository.listExpenses('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/split/expenses'));
      expect(expenses.single.id, 'e1');
    });

    test('listExpenses GETs /api/split/expenses?group_id= when filtered by group', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'expenses': <Map<String, dynamic>>[]}), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      await repository.listExpenses('token-123', groupId: 'g1');

      expect(capturedUri!.queryParameters, {'group_id': 'g1'});
    });

    test('listExpenses GETs /api/split/expenses?with= when filtered by counterparty', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'expenses': <Map<String, dynamic>>[]}), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      await repository.listExpenses('token-123', withUserId: 'u2');

      expect(capturedUri!.queryParameters, {'with': 'u2'});
    });

    test('createExpense POSTs full body (equal split) to /api/split/expenses', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_expenseJson()), 201);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final expense = await repository.createExpense(
        'token-123',
        groupId: 'g1',
        payerUserId: 'u1',
        amount: 900,
        currency: 'TWD',
        description: 'Dinner',
        day: '2026-08-02',
        split: const EqualSplitInput(['u1', 'u2']),
      );

      expect(capturedUri, Uri.parse('https://example.test/api/split/expenses'));
      expect(capturedMethod, 'POST');
      expect(capturedBody, {
        'group_id': 'g1',
        'payer_user_id': 'u1',
        'amount': 900,
        'currency': 'TWD',
        'description': 'Dinner',
        'day': '2026-08-02',
        'split': {
          'mode': 'equal',
          'participant_user_ids': ['u1', 'u2'],
        },
      });
      expect(expense.id, 'e1');
    });

    test('createExpense omits group_id when null (a one-off, group-less expense)', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_expenseJson()), 201);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      await repository.createExpense(
        'token-123',
        payerUserId: 'u1',
        amount: 900,
        currency: 'TWD',
        description: 'Dinner',
        day: '2026-08-02',
        split: const ExactSplitInput([ExactShareInput(userId: 'u1', amount: 900)]),
      );

      expect(capturedBody!.containsKey('group_id'), isFalse);
      expect(capturedBody!['split'], {
        'mode': 'exact',
        'shares': [
          {'user_id': 'u1', 'amount': 900},
        ],
      });
    });

    test('getExpense GETs /api/split/expenses/:id', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_expenseJson()), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final expense = await repository.getExpense('token-123', 'e1');

      expect(capturedUri, Uri.parse('https://example.test/api/split/expenses/e1'));
      expect(expense.id, 'e1');
    });

    test('updateExpense PATCHes the full body to /api/split/expenses/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_expenseJson()), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final expense = await repository.updateExpense(
        'token-123',
        'e1',
        payerUserId: 'u1',
        amount: 900,
        currency: 'TWD',
        description: 'Dinner (edited)',
        day: '2026-08-02',
        split: const EqualSplitInput(['u1', 'u2']),
      );

      expect(capturedUri, Uri.parse('https://example.test/api/split/expenses/e1'));
      expect(capturedMethod, 'PATCH');
      expect(capturedBody!['description'], 'Dinner (edited)');
      expect(capturedBody!.containsKey('group_id'), isFalse);
      expect(expense.id, 'e1');
    });

    test('deleteExpense DELETEs to /api/split/expenses/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(jsonEncode({'deleted': true}), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      await repository.deleteExpense('token-123', 'e1');

      expect(capturedUri, Uri.parse('https://example.test/api/split/expenses/e1'));
      expect(capturedMethod, 'DELETE');
    });

    test('getBalances GETs /api/split/balances', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_balancesJson()), 200);
      });
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      final balances = await repository.getBalances('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/split/balances'));
      expect(balances.single.displayName, 'Bo');
    });

    test('throws SplitReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('', 401));
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.listGroups('token-123'),
        throwsA(isA<SplitReauthenticationRequired>()),
      );
    });

    test('throws SplitFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('boom'));
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      expect(() => repository.listGroups('token-123'), throwsA(isA<SplitFetchFailure>()));
    });

    test('throws SplitNotFound on 404', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'not_found'}), 404),
      );
      final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

      expect(() => repository.getGroup('token-123', 'g1'), throwsA(isA<SplitNotFound>()));
    });

    group('all ten 400 error codes', () {
      Future<void> expectMapped(String errorCode, Matcher matcher, {String? message}) async {
        final body = message == null
            ? {'error': errorCode}
            : {'error': errorCode, 'message': message};
        final client = MockClient((request) async => http.Response(jsonEncode(body), 400));
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        await expectLater(() => repository.archiveGroup('token-123', 'g1'), throwsA(matcher));
      }

      test('not_friends -> NotFriends', () => expectMapped('not_friends', isA<NotFriends>()));

      test(
        'not_a_group_member -> NotAGroupMember',
        () => expectMapped('not_a_group_member', isA<NotAGroupMember>()),
      );

      test('group_archived -> GroupArchived', () => expectMapped('group_archived', isA<GroupArchived>()));

      test('split_too_small -> SplitTooSmall', () => expectMapped('split_too_small', isA<SplitTooSmall>()));

      test(
        'duplicate_participant -> DuplicateParticipant',
        () => expectMapped('duplicate_participant', isA<DuplicateParticipant>()),
      );

      test(
        'already_a_group_member -> AlreadyAGroupMember',
        () => expectMapped('already_a_group_member', isA<AlreadyAGroupMember>()),
      );

      test(
        'not_a_participant -> NotAParticipant',
        () => expectMapped('not_a_participant', isA<NotAParticipant>()),
      );

      test('shares_do_not_sum_to_amount -> SharesDoNotSumToAmount carrying message', () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'shares_do_not_sum_to_amount', 'message': 'short by 100'}),
            400,
          ),
        );
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        await expectLater(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(
            isA<SharesDoNotSumToAmount>().having((e) => e.message, 'message', 'short by 100'),
          ),
        );
      });

      test('invalid_split_input -> InvalidSplitInput carrying message', () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'invalid_split_input', 'message': 'bad shape'}),
            400,
          ),
        );
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        await expectLater(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<InvalidSplitInput>().having((e) => e.message, 'message', 'bad shape')),
        );
      });

      test('bad_request -> SplitBadRequest carrying message', () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'bad_request', 'message': 'name is required'}),
            400,
          ),
        );
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        await expectLater(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<SplitBadRequest>().having((e) => e.message, 'message', 'name is required')),
        );
      });

      test('unrecognised 400 error code throws SplitFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'something_else'}), 400),
        );
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<SplitFetchFailure>()),
        );
      });

      test('500 throws SplitFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'internal'}), 500),
        );
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<SplitFetchFailure>()),
        );
      });
    });

    group('malformed error bodies never throw a decode error', () {
      test('empty body on a 400 falls back to SplitFetchFailure', () async {
        final client = MockClient((request) async => http.Response('', 400));
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<SplitFetchFailure>()),
        );
      });

      test('non-JSON body on a 400 falls back to SplitFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response('<html>not json</html>', 400),
        );
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<SplitFetchFailure>()),
        );
      });

      test('empty body on a 401 still throws SplitReauthenticationRequired', () async {
        final client = MockClient((request) async => http.Response('', 401));
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.archiveGroup('token-123', 'g1'),
          throwsA(isA<SplitReauthenticationRequired>()),
        );
      });

      test('malformed 200 body throws SplitFetchFailure, not a decode error', () async {
        final client = MockClient((request) async => http.Response('not json', 200));
        final repository = HttpSplitRepository(baseUrl: 'https://example.test', client: client);

        expect(() => repository.listGroups('token-123'), throwsA(isA<SplitFetchFailure>()));
      });
    });
  });
}
