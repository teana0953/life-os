import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/assistant/application/send_assistant_message.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_chat_context.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_controller.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/list_finance_categories.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart';
import 'contexts/assistant/assistant_test_support.dart';
import 'contexts/finance/finance_test_support.dart';

/// Guards `app.dart`'s actual `/assistant` route wiring — `key:
/// ValueKey(state.uri.query)` and `chatContext:
/// AssistantChatContext.fromQuery(...)` — the same shape as the `/invite`
/// guard in app_social_routing_test.dart (design D13's lesson: go_router's
/// `pageKey` tracks only the path pattern, not the query).
void main() {
  group('App assistant context routing', () {
    testWidgets(
      'a second /assistant entry (different context, no leaving the app) '
      'carries its OWN context — not silently dropped by a State the first '
      'visit already consumed (app.dart: AssistantScreen key: '
      'ValueKey(state.uri.query))',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(
          UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'user@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
            isAdmin: false,
          ),
        );
        SharedPreferences.setMockInitialValues({});
        final geminiKeyController = GeminiKeyController(
          await SharedPreferences.getInstance(),
        );
        await geminiKeyController.setKey('test-key');
        final assistantRepository = RecordingAssistantRepository();
        final financeRepository = FakeFinanceRepository();
        final assistantController = AssistantController(
          SendAssistantMessage(assistantRepository),
          AddTransaction(financeRepository),
          ListFinanceCategories(financeRepository),
        );

        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          assistantController: assistantController,
          geminiKeyController: geminiKeyController,
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('settings-icon-button'))),
        );
        const contextA = AssistantChatContext(
          tab: 'transactions',
          month: '2025-11',
        );
        const contextB = AssistantChatContext(tab: 'split');

        router.go('/assistant?ctx=finance&tab=transactions&month=2025-11');
        await tester.pumpAndSettle();
        // A live BuildContext inside the assistant screen — needed by
        // `label`, which renders the month through the locale-aware
        // `monthYearLabel` convention (design E) rather than a raw string.
        final contextALabel = contextA.label(
          tester.element(find.byKey(const Key('assistant-composer-field'))),
        );
        await tester.enterText(
          find.byKey(const Key('assistant-composer-field')),
          'first',
        );
        await tester.tap(find.byKey(const Key('assistant-send-button')));
        await tester.pumpAndSettle();

        expect(assistantRepository.calls, hasLength(1));
        expect(
          assistantRepository.calls[0].single.content,
          '$contextALabel\nfirst',
        );

        // Without leaving the app, enter again with a DIFFERENT context —
        // exactly the `/invite` shape (design D13), one route, no pop.
        router.go('/assistant?ctx=finance&tab=split');
        await tester.pumpAndSettle();
        final contextBLabel = contextB.label(
          tester.element(find.byKey(const Key('assistant-composer-field'))),
        );
        await tester.enterText(
          find.byKey(const Key('assistant-composer-field')),
          'second',
        );
        await tester.tap(find.byKey(const Key('assistant-send-button')));
        await tester.pumpAndSettle();

        expect(assistantRepository.calls, hasLength(2));
        // `.last`, not `.single`: the controller is app-lifetime, so the
        // second send replays the whole transcript (turn 1, its reply, then
        // this turn).
        //
        // The second visit's newest message must carry ITS OWN context line.
        // Drop `key: ValueKey(state.uri.query)` from app.dart and the old
        // `State` (and its already-consumed `_contextPrefixed` flag) is
        // reused: this turns into a bare `'second'` with no context line at
        // all — silently dropping contextB's label.
        expect(
          assistantRepository.calls[1].last.content,
          '$contextBLabel\nsecond',
        );
        // And the replayed first turn keeps contextA — the two visits'
        // contexts never bleed into one another.
        expect(
          assistantRepository.calls[1].first.content,
          '$contextALabel\nfirst',
        );
      },
    );
  });
}
