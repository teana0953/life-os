import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/assistant/application/send_assistant_message.dart';
import 'package:life_os/contexts/assistant/domain/assistant_failure.dart';
import 'package:life_os/contexts/assistant/domain/assistant_message.dart';
import 'package:life_os/contexts/assistant/domain/transaction_draft.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_controller.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_screen.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/list_finance_categories.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_money.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../assistant_test_support.dart';

/// The stored key in every test. If this string is ever findable on screen,
/// the render-canary sweep names the leak. `-9137` keeps its `last4` from
/// colliding with any amount fixture.
const _canaryKey = 'SK-RENDER-CANARY-9137';

/// Pinned well away from the real today (see the controller test).
final _now = DateTime(2031, 3, 15, 9, 30);

final _loc = lookupAppLocalizations(const Locale('en'));

class _Harness {
  final AssistantController controller;
  final RecordingAssistantRepository assistantRepository;
  final GatedFinanceRepository financeRepository;
  final GeminiKeyController keyController;
  int signOutCalls = 0;

  _Harness(
    this.controller,
    this.assistantRepository,
    this.financeRepository,
    this.keyController,
  );
}

Future<_Harness> _pumpScreen(
  WidgetTester tester, {
  bool withKey = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final keyController = GeminiKeyController(await SharedPreferences.getInstance());
  if (withKey) await keyController.setKey(_canaryKey);
  final assistantRepository = RecordingAssistantRepository();
  final financeRepository = GatedFinanceRepository();
  final controller = AssistantController(
    SendAssistantMessage(assistantRepository),
    AddTransaction(financeRepository),
    ListFinanceCategories(financeRepository),
    clock: () => _now,
  );
  final harness =
      _Harness(controller, assistantRepository, financeRepository, keyController);
  await tester.pumpWidget(
    l10nRouterTestApp(
      theme: lightTheme,
      home: AssistantScreen(
        controller: controller,
        geminiKeyController: keyController,
        idToken: () async => 'token-1',
        onSignInAgain: () => harness.signOutCalls++,
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _sendText(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('assistant-composer-field')), text);
  await tester.tap(find.byKey(const Key('assistant-send-button')));
  await tester.pump();
}

AssistantProposal _foodProposal({int amount = 1234}) => AssistantProposal(
  kind: 'create_transaction',
  // currency and day deliberately absent — the draft fills them, and the
  // render-equals-write test watches both sides agree on the filled values.
  fields: {'type': 'expense', 'amount': amount, 'category_name': '餐飲'},
);

/// Every place a string can reach a person: painted text, tooltips (hover,
/// long-press, and screen readers), and the semantics tree.
///
/// `find.textContaining` alone reads `Text` and `EditableText` and nothing
/// else — measured: interpolating the key into the send button's tooltip left
/// all fifteen screen tests green. Two earlier guards in this same change
/// died the same way, by asserting about somewhere the secret could not
/// reach.
void _expectNoCanary(WidgetTester tester, String state) {
  const canary = 'SK-RENDER-CANARY';
  expect(
    find.textContaining(canary, skipOffstage: false),
    findsNothing,
    reason: 'the full key leaked into painted text in the "$state" state',
  );

  final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip, skipOffstage: false));
  expect(
    tooltips.where((tooltip) => tooltip.message?.contains(canary) ?? false),
    isEmpty,
    reason: 'the full key leaked into a tooltip in the "$state" state',
  );

  final semantics = tester.widgetList<Semantics>(find.byType(Semantics, skipOffstage: false));
  expect(
    semantics.where((node) {
      final properties = node.properties;
      return (properties.label?.contains(canary) ?? false) ||
          (properties.value?.contains(canary) ?? false) ||
          (properties.hint?.contains(canary) ?? false) ||
          (properties.tooltip?.contains(canary) ?? false);
    }),
    isEmpty,
    reason: 'the full key leaked into the semantics tree in the "$state" state',
  );
}

void main() {
  group('AssistantScreen setup state', () {
    testWidgets('no key: entry is alive, setup + settings exit shown, '
        'composer absent — and pasting a key revives it WITHOUT remount', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester, withKey: false);

      expect(find.byKey(const Key('assistant-setup')), findsOneWidget);
      expect(
        find.byKey(const Key('assistant-setup-settings-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('assistant-composer-field')), findsNothing);

      // The user goes to settings, pastes a key, comes back: the SAME mounted
      // screen must flip to the live composer. A build-time `hasKey` capture
      // stays dead here.
      await harness.keyController.setKey(_canaryKey);
      await tester.pump();

      expect(find.byKey(const Key('assistant-setup')), findsNothing);
      expect(find.byKey(const Key('assistant-composer-field')), findsOneWidget);
    });

    testWidgets('the setup state says why a key that was already set is gone: '
        'sign-out clears it', (tester) async {
      await _pumpScreen(tester, withKey: false);

      // Asserting on the localized string, not just the key: the notice's
      // whole job is to name sign-out as the cause. A widget that renders the
      // right key with unrelated copy would leave the returning user with the
      // same "I set this yesterday" confusion this line exists to answer.
      expect(
        find.byKey(const Key('assistant-setup-sign-out-notice')),
        findsOneWidget,
      );
      expect(find.text(_loc.assistantSetupSignOutNotice), findsOneWidget);
    });

    testWidgets('the setup settings button navigates to /settings', (
      tester,
    ) async {
      await _pumpScreen(tester, withKey: false);
      await tester.tap(find.byKey(const Key('assistant-setup-settings-button')));
      await tester.pumpAndSettle();
      expect(find.text('/settings'), findsOneWidget);
    });
  });

  group('AssistantScreen errors', () {
    testWidgets('the four error-row failures render four DIFFERENT texts, '
        'and only the key-shaped ones offer a settings exit', (tester) async {
      final rendered = <String>{};
      const cases = [
        (AssistantFailure.keyRejected, true),
        (AssistantFailure.quotaExhausted, false),
        (AssistantFailure.modelUnavailable, true),
        (AssistantFailure.serviceUnavailable, false),
      ];
      for (final (failure, pointsToSettings) in cases) {
        final harness = await _pumpScreen(tester);
        harness.assistantRepository.failure = AssistantSendFailure(failure);
        await _sendText(tester, 'hello');
        await tester.pumpAndSettle();

        final errorText = tester
            .widget<Text>(find.byKey(const Key('assistant-error-text')))
            .data!;
        rendered.add(errorText);
        expect(
          find.byKey(const Key('assistant-error-settings-button')),
          pointsToSettings ? findsOneWidget : findsNothing,
          reason: '$failure settings-button asymmetry',
        );
        expect(find.byKey(const Key('assistant-retry-button')), findsOneWidget);
        _expectNoCanary(tester, '$failure');
      }
      // An implementation that collapses everything into one sentence cannot
      // reach 4 distinct strings.
      expect(rendered, hasLength(4));
    });

    testWidgets('missingKey (key cleared in another tab) falls back to the '
        'setup state, not an error row', (tester) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.failure =
          const AssistantSendFailure(AssistantFailure.missingKey);
      await _sendText(tester, 'hello');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-setup')), findsOneWidget);
      expect(find.byKey(const Key('assistant-error-text')), findsNothing);
      _expectNoCanary(tester, 'missingKey');
    });

    testWidgets('and pasting a key gets the conversation back', (tester) async {
      // The half the original test did not cover: it proved the screen falls
      // into the setup state, not that anyone can climb out. `_lastError` is
      // cleared only by send/retry/reset, and the setup state shows neither
      // the composer nor the retry button — so a valid key pasted afterwards
      // used to leave the user reading "add a key" forever. The controller is
      // an app-lifetime singleton, so re-navigating did not help; only
      // signing out or reloading did.
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.failure =
          const AssistantSendFailure(AssistantFailure.missingKey);
      await _sendText(tester, 'hello');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-setup')), findsOneWidget);

      // What the user does next: settings, paste, back.
      await harness.keyController.setKey('AIzaSy-A-DIFFERENT-KEY-5150');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-setup')), findsNothing);
      expect(find.byKey(const Key('assistant-composer-field')), findsOneWidget);
    });

    testWidgets('a network failure reads as the service-unavailable copy', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.failure =
          const AssistantSendFailure(AssistantFailure.network);
      await _sendText(tester, 'hello');
      await tester.pumpAndSettle();

      expect(find.text(_loc.assistantErrorUnavailable), findsOneWidget);
      expect(
        find.byKey(const Key('assistant-error-settings-button')),
        findsNothing,
      );
    });

    testWidgets('the error settings button navigates to /settings', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.failure =
          const AssistantSendFailure(AssistantFailure.keyRejected);
      await _sendText(tester, 'hello');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assistant-error-settings-button')));
      await tester.pumpAndSettle();
      expect(find.text('/settings'), findsOneWidget);
    });

    testWidgets('retry re-sends without duplicating the user bubble', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.failure =
          const AssistantSendFailure(AssistantFailure.serviceUnavailable);
      await _sendText(tester, 'only once');
      await tester.pumpAndSettle();
      expect(find.text('only once'), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-retry-button')));
      await tester.pumpAndSettle();

      expect(find.text('only once'), findsOneWidget);
      final calls = harness.assistantRepository.calls;
      expect(calls, hasLength(2));
      expect(
        calls[1].map((m) => '${m.role}:${m.content}').toList(),
        calls[0].map((m) => '${m.role}:${m.content}').toList(),
      );
      expect(find.byKey(const Key('assistant-error-text')), findsNothing);
    });

    testWidgets('the reply is rendered as Markdown, the user\'s own line is '
        'not', (tester) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply = const AssistantReply(
        text: '總花費為 **NT\$ 23,847**。\n* 醫療：NT\$ 21,200',
        proposals: [],
      );
      // A star the user typed themselves — it is still visible in what they
      // sent, so the transcript must show it, not turn it into a bullet.
      // The fixture must be one the parser would transform (bullet marker at
      // start), so that if someone accidentally applies AssistantMarkdown to
      // user messages, the test catches it: the literal star disappears when
      // parsed as a bullet item.
      await _sendText(tester, '* 3 加 2 是多少');
      await tester.pumpAndSettle();

      // The literal star and number must remain in the user's message.
      expect(find.textContaining('* 3 加 2 是多少'), findsOneWidget);
      // No bold markers in the reply (they are eaten and rendered as weight).
      expect(find.textContaining('**', findRichText: true), findsNothing);
      // The assistant's reply has a bullet marker.
      expect(find.text('•'), findsOneWidget);
    });

    testWidgets('401 replaces the screen with the sign-in-again exit', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.failure = const AssistantReauthRequired();
      await _sendText(tester, 'hello');
      await tester.pumpAndSettle();

      final signInAgain = find.byKey(const Key('assistant-sign-in-again-button'));
      expect(signInAgain, findsOneWidget);
      expect(find.byKey(const Key('assistant-composer-field')), findsNothing);
      await tester.tap(signInAgain);
      expect(harness.signOutCalls, 1);
    });
  });

  group('AssistantScreen proposal cards', () {
    testWidgets('what the card SHOWS is what accept WRITES — one draft, '
        'both sides', (tester) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply =
          AssistantReply(text: '要記下這筆嗎?', proposals: [_foodProposal()]);
      await _sendText(tester, '幫我記帳');
      await tester.pumpAndSettle();

      final amountText = tester
          .widget<Text>(find.byKey(const Key('assistant-proposal-amount-1-0')))
          .data!;
      final dayText = tester
          .widget<Text>(find.byKey(const Key('assistant-proposal-day-1-0')))
          .data!;
      final categoryText = tester
          .widget<Text>(find.byKey(const Key('assistant-proposal-category-1-0')))
          .data!;

      await tester.tap(find.byKey(const Key('assistant-proposal-accept-1-0')));
      await tester.pumpAndSettle();

      final saved = harness.financeRepository.byMonth['2031-03']!.single;
      // The displayed strings are re-derived here from the WRITTEN record: a
      // second normalization pass anywhere (render-side default, write-side
      // default) makes the two sides disagree on the proposal's absent
      // currency/day and turns this red.
      expect(
        amountText,
        contains(formatMinorUnitsForDisplay(saved.amount, saved.currency)),
      );
      expect(amountText, contains(saved.currency));
      expect(dayText, contains(saved.date));
      expect(saved.date, '2031-03-15');
      expect(saved.currency, 'TWD');
      expect(categoryText, contains('餐飲'));
      expect(saved.categoryId, 'cat-food');
    });

    testWidgets('the accept button cannot record twice: disabled while '
        'saving, gone once saved', (tester) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply =
          AssistantReply(text: 'ok', proposals: [_foodProposal()]);
      harness.financeRepository.addGate = Completer<void>();
      await _sendText(tester, '記一筆');
      await tester.pumpAndSettle();

      final accept = find.byKey(const Key('assistant-proposal-accept-1-0'));
      await tester.tap(accept);
      await tester.pump();
      // Second tap lands while the save is in flight.
      await tester.tap(accept, warnIfMissed: false);
      await tester.pump();
      expect(harness.financeRepository.addTransactionCalls, 1);
      _expectNoCanary(tester, 'saving');

      harness.financeRepository.addGate!.complete();
      await tester.pumpAndSettle();

      expect(harness.financeRepository.addTransactionCalls, 1);
      expect(accept, findsNothing);
      expect(
        find.byKey(const Key('assistant-proposal-saved-1-0')),
        findsOneWidget,
      );
      // Even a direct controller call cannot revive the saved card.
      await harness.controller.accept('token-1', 1, 0);
      expect(harness.financeRepository.addTransactionCalls, 1);
    });

    testWidgets('a failed save says so on the card and re-arms the button', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply =
          AssistantReply(text: 'ok', proposals: [_foodProposal()]);
      harness.financeRepository.failNext = const FinanceFetchFailure('boom');
      await _sendText(tester, '記一筆');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assistant-proposal-accept-1-0')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('assistant-proposal-save-failed-1-0')),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('assistant-proposal-accept-1-0')),
      );
      expect(button.onPressed, isNotNull);
      _expectNoCanary(tester, 'save failed');
    });

    testWidgets('an unknown category is named on the card, and the button '
        'still works once the category exists', (tester) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply = const AssistantReply(
        text: 'ok',
        proposals: [
          AssistantProposal(
            kind: 'create_transaction',
            fields: {
              'type': 'expense',
              'amount': 250,
              'category_name': '寵物旅館',
            },
          ),
        ],
      );
      await _sendText(tester, '記一筆');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assistant-proposal-accept-1-0')));
      await tester.pumpAndSettle();

      expect(
        find.text(_loc.assistantProposalCategoryNotFound('寵物旅館')),
        findsOneWidget,
      );
      expect(harness.financeRepository.addTransactionCalls, 0);

      // The message says "go and create it", so the button has to still be
      // there when they come back. A dead button would make that a lie and
      // force them to retype the whole request for a fresh card.
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('assistant-proposal-accept-1-0')),
      );
      expect(button.onPressed, isNotNull);

      // They create it, come back, press again.
      harness.financeRepository.categoriesToReturn = [
        ...harness.financeRepository.categoriesToReturn,
        const FinanceCategory(
          id: 'cat-pets',
          name: '寵物旅館',
          type: FinanceType.expense,
          icon: 'other',
          sortOrder: 9,
          archived: false,
        ),
      ];
      await tester.tap(find.byKey(const Key('assistant-proposal-accept-1-0')));
      await tester.pumpAndSettle();

      expect(harness.financeRepository.addTransactionCalls, 1);
      expect(find.byKey(const Key('assistant-proposal-saved-1-0')), findsOneWidget);
    });

    testWidgets('an unrenderable proposal shows no accept button at all', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply = const AssistantReply(
        text: 'ok',
        proposals: [
          AssistantProposal(
            kind: 'create_transaction',
            fields: {'type': 'expense', 'amount': 0},
          ),
        ],
      );
      await _sendText(tester, '記一筆');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('assistant-proposal-unrenderable-1-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('assistant-proposal-accept-1-0')),
        findsNothing,
      );
    });
  });

  group('AssistantScreen key never renders', () {
    testWidgets('the full key appears in NO state: empty, sending, replied, '
        'card states', (tester) async {
      final harness = await _pumpScreen(tester);
      _expectNoCanary(tester, 'idle empty');

      // In flight.
      harness.assistantRepository.gate = Completer<void>();
      harness.assistantRepository.reply =
          AssistantReply(text: '好', proposals: [_foodProposal()]);
      await _sendText(tester, '記一筆');
      expect(
        find.byKey(const Key('assistant-sending-indicator')),
        findsOneWidget,
      );
      _expectNoCanary(tester, 'sending');

      // Replied, card pending.
      harness.assistantRepository.gate!.complete();
      await tester.pumpAndSettle();
      _expectNoCanary(tester, 'card pending');

      // Saved.
      await tester.tap(find.byKey(const Key('assistant-proposal-accept-1-0')));
      await tester.pumpAndSettle();
      _expectNoCanary(tester, 'card saved');
    });
  });

  group('AssistantScreen empty-state examples', () {
    testWidgets('tapping an example fills the composer and focuses it — and '
        'sends nothing', (tester) async {
      final harness = await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('assistant-example-log')));
      await tester.pumpAndSettle();

      // Read off the live EditableText, not the localization constant alone:
      // a chip that painted the right label but wrote a different string into
      // the field would otherwise pass.
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('assistant-composer-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.controller.text, _loc.assistantExampleLog);
      // Caret at the end — a `TextEditingController(text: …)` assignment
      // leaves it at 0, so the user's next keystroke would prepend.
      expect(
        editable.controller.selection.baseOffset,
        _loc.assistantExampleLog.length,
      );
      expect(
        editable.focusNode.hasFocus,
        isTrue,
        reason: 'the example must land in a field the user is already typing in',
      );

      // The load-bearing half: filling is not sending. Two of the three
      // examples are templates to edit, and a chip that sent would spend the
      // user's own Gemini quota on a stray tap.
      expect(harness.assistantRepository.calls, isEmpty);
      expect(find.byKey(const Key('assistant-sending-indicator')), findsNothing);
    });

    testWidgets('the examples are the empty state only — they leave once the '
        'transcript has a message', (tester) async {
      final harness = await _pumpScreen(tester);
      expect(find.byKey(const Key('assistant-example-spend')), findsOneWidget);
      expect(find.byKey(const Key('assistant-example-owe')), findsOneWidget);

      harness.assistantRepository.reply =
          const AssistantReply(text: '好', proposals: []);
      await _sendText(tester, '這個月花多少?');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assistant-example-spend')), findsNothing);
      expect(find.byKey(const Key('assistant-example-log')), findsNothing);
      expect(find.byKey(const Key('assistant-example-owe')), findsNothing);
      expect(find.byKey(const Key('assistant-empty-hint')), findsNothing);
    });

    testWidgets('320dp × textScale 2.0: hint and all three examples lay out '
        'without errors and every chip is reachable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      await expectNoLayoutErrors(() async {
        await _pumpScreen(tester);
        // Scrolled to, not merely found: at this text scale the chips sit
        // below the fold of the transcript area, and `findsOneWidget` alone
        // would pass on a column that clipped them out of reach.
        for (final key in const [
          'assistant-example-spend',
          'assistant-example-log',
          'assistant-example-owe',
        ]) {
          await tester.ensureVisible(find.byKey(Key(key)));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key(key)));
          await tester.pumpAndSettle();
        }
      });

      // The last tap landed: taps that miss only warn, so without this the
      // loop above proves nothing about reachability.
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('assistant-composer-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.controller.text, _loc.assistantExampleOwe);
    });
  });

  group('AssistantScreen narrow layout', () {
    testWidgets('320dp × textScale 3.0: transcript, card, error row and '
        'composer all lay out without errors and the composer stays usable', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // 3.0, not 2.0 — the level-3 nested item below (mirroring the
      // unit-level regression test's parameters) has enough slack at 2.0 to
      // not squeeze the body even with the fix's indent cap deleted; only
      // 3.0 actually exercises the regression this guard exists for.
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      await expectNoLayoutErrors(() async {
        final harness = await _pumpScreen(tester);
        harness.assistantRepository.reply = AssistantReply(
          // Worst case for the Markdown gutter/indent path, not a plain
          // sentence: a numbered list plus a level-3 nested bullet with a
          // long unbreakable run. A fixed-px gutter/indent overflows this
          // horizontally at 320dp × textScale 2.0 without erroring — the
          // nested line just silently shrinks to zero width — so a guard
          // built only from a plain sentence never renders this path at all.
          // Level 3 (six leading spaces), not level 2 — measured: a level-2
          // item at this width/scale leaves the fixed-indent bug too much
          // slack to actually squeeze the body, so it stays green with or
          // without the fix. Level 3 mirrors the unit-level regression test
          // at assistant_markdown_test.dart that the fix was written for.
          text: '這個月餐飲共花了 3,600 元：\n'
              '1. 早餐 500 元\n'
              '2. 晚餐 3,100 元\n'
              '* 醫療\n'
              '      * 掛號費用一百元這一段故意寫得很長很長很長很長很長很長不許換行',
          proposals: [
            const AssistantProposal(
              kind: 'create_transaction',
              fields: {
                'type': 'expense',
                'amount': 123456789,
                'currency': 'USD',
                'category_name': '一個名字很長很長的分類',
                'note': '一段很長很長很長的備註文字,用來逼出換行與溢位',
              },
            ),
          ],
        );
        await _sendText(tester, '幫我記一筆昨天晚上跟朋友聚餐的錢,大概三千六');
        await tester.pumpAndSettle();

        // Not just "no layout error" — the nested list line must actually
        // have width. A fixed-px gutter/indent silently squeezes it to zero
        // width instead of throwing, which the layout-error guard alone
        // cannot see. `greaterThan(20)` at level 2 stayed green with the
        // fix's cap deleted entirely — 320dp of width gives a level-2 item
        // enough slack to not visibly squeeze. Level 3 above closes that
        // gap; the threshold itself is raised to a width an actual
        // multi-character line needs, not a number that a single clipped
        // glyph could also satisfy.
        expect(
          tester.getSize(find.textContaining('掛號費用', findRichText: true).first).width,
          greaterThan(60),
        );

        // Then an error row on top of all that.
        harness.assistantRepository.failure =
            const AssistantSendFailure(AssistantFailure.keyRejected);
        await _sendText(tester, '再問一句');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-error-text')), findsOneWidget);

        // The composer is still on screen and still takes input — the
        // keyboard-up analogue of this repo's food-search guard.
        //
        // The focus assertion is the load-bearing one. `tap` on something
        // unreachable only warns, and `enterText` focuses the field itself
        // without hit-testing — measured: wrapping the composer in an
        // `IgnorePointer`, so no real finger could reach it, left all fifteen
        // screen tests green.
        await tester.tap(find.byKey(const Key('assistant-composer-field')));
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('assistant-composer-field')),
            matching: find.byType(EditableText),
          ),
        );
        expect(
          editable.focusNode.hasFocus,
          isTrue,
          reason: 'the tap did not land on the composer — it is on screen but not reachable',
        );
        await tester.enterText(
          find.byKey(const Key('assistant-composer-field')),
          '鍵盤彈出時還打得了字',
        );
        expect(find.text('鍵盤彈出時還打得了字'), findsOneWidget);
      }, reason: '320dp × textScale 2.0 must not overflow');
    });
  });

  group('the composer on a hardware keyboard', () {
    testWidgets('Enter sends, Shift+Enter does not', (tester) async {
      // A multi-line TextField swallows Enter: `onSubmitted` fires for a
      // single-line one and for the on-screen keyboard's send action, but on
      // a desktop or the web the message just sits there with a newline in
      // it. Both halves are asserted — a handler that sends on every Enter
      // would take Shift+Enter away, which is how every chat box on that
      // platform inserts a line break.
      final harness = await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('assistant-composer-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('assistant-composer-field')), '第一行');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(harness.assistantRepository.calls, isEmpty, reason: 'Shift+Enter must not send');

      // Not sending is only half of it: the newline has to reach the field.
      // A handler that returned `handled` for Shift+Enter would swallow the
      // key and silently drop the line break, and the assertion above alone
      // stayed green through exactly that mutation. Widget tests do not
      // insert text from hardware key events, so the observable is the
      // handler's own verdict: it must leave the key alone.
      final wrapper = tester.widget<Focus>(
        find.ancestor(
          of: find.byKey(const Key('assistant-composer-field')),
          matching: find.byType(Focus),
        ).first,
      );
      final shiftEnter = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(
        wrapper.onKeyEvent!(FocusNode(), shiftEnter),
        KeyEventResult.ignored,
        reason: 'Shift+Enter must pass through to the field, or the newline is swallowed',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(harness.assistantRepository.calls, hasLength(1));
    });

    testWidgets('Enter confirming an IME candidate does not send', (tester) async {
      // How every Chinese and Japanese input method commits a word: the
      // candidate window is open, Enter picks the highlighted one. Treating
      // that as send fires off half-composed text — and worse, returning
      // `handled` eats the confirmation itself, because the embedder only
      // forwards a key the framework left alone. zh-Hant is this app's other
      // locale, so this is the common case, not an edge one.
      final harness = await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('assistant-composer-field')));
      await tester.pumpAndSettle();
      // A live Zhuyin candidate: '吃拉' is committed, 'ㄇㄧㄢ' is still being
      // composed — exactly the shape the engines report.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '吃拉ㄇㄧㄢ',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 2, end: 5),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.assistantRepository.calls, isEmpty);

      // And once the composition is committed, Enter sends as it should —
      // otherwise "never sends while composing" could be satisfied by never
      // sending at all.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: '吃拉麵', selection: TextSelection.collapsed(offset: 3)),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.assistantRepository.calls, hasLength(1));
    });

    testWidgets('the key handler is not itself a tab stop', (tester) async {
      // The wrapper exists to watch keys bubbling up from the field. Left
      // focusable — the default — it also becomes a tab target of its own,
      // with no visible focus ring and no text entry: a keyboard-only user
      // tabs to the composer, types, and nothing appears until they press
      // Tab again.
      //
      // Asserted on the two properties rather than by walking the traversal
      // order: those properties *are* what makes a node a stop, and a
      // traversal walk written here passed with them removed — it was
      // measuring the wrong thing, which is the mistake this whole change
      // keeps making.
      await _pumpScreen(tester);

      final wrapper = tester.widget<Focus>(
        find.ancestor(
          of: find.byKey(const Key('assistant-composer-field')),
          matching: find.byType(Focus),
        ).first,
      );

      expect(wrapper.canRequestFocus, isFalse);
      expect(wrapper.skipTraversal, isTrue);
    });
  });

  group('transcript width', () {
    testWidgets('a proposal card is capped like the bubbles beside it', (tester) async {
      // Two card-shaped things in one transcript growing to different widths
      // on a wide window reads as two unrelated components. The surface is
      // deliberately far wider than the cap, or both would be constrained by
      // the window instead and the assertion would pass on nothing.
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply = const AssistantReply(
        // Both long enough to exceed the cap on a 1400px window — otherwise
        // each renders at its content width and the comparison says nothing
        // about clamping.
        text: '這是一段刻意寫得很長的回覆,長到在一四〇〇像素寬的視窗上一定會撞到寬度上限,'
            '而不是停在自己的內容寬度,這樣才量得到夾住這件事本身,而不是量到內容有多長。',
        proposals: [
          AssistantProposal(
            kind: 'create_transaction',
            fields: {
              'type': 'expense',
              'amount': 250,
              'category_name': '餐飲',
              'note': '一段同樣刻意寫得很長的備註,長到這張卡片在寬視窗上也一定會撞到同一個寬度上限,'
                  '否則卡片會停在自己的內容寬度而不是被夾住。',
            },
          ),
        ],
      );
      await _sendText(tester, '記一筆');
      await tester.pumpAndSettle();

      // Against the bubble, not against a number: what matters is that the
      // two agree. A bare `<= 560` passed with the cap removed, because at
      // this width some ancestor was holding the card in anyway — the
      // assertion was measuring that, not the cap.
      final cardWidth = tester.getSize(find.byKey(const Key('assistant-proposal-card-1-0'))).width;
      final bubbleWidth = tester
          .getSize(find.ancestor(
            of: find.textContaining('這是一段刻意寫得很長的回覆'),
            matching: find.byType(ConstrainedBox),
          ).first)
          .width;
      expect(bubbleWidth, 560, reason: 'the bubble must actually be at its cap, or this proves nothing');
      expect(cardWidth, bubbleWidth);
    });

    testWidgets('a short list reply hugs its content, not the real bubble path\'s width unit test alone', (tester) async {
      // The unit test in assistant_markdown_test.dart proves the Row inside
      // AssistantMarkdown hugs its content in an isolated harness. It does
      // not prove the real bubble — Container -> ConstrainedBox(560) ->
      // AssistantMarkdown — stays narrow too. Widening the bubble Container
      // to `width: double.infinity` (exactly the symptom the fix targets)
      // must turn this red even though the unit test alone stays green.
      final harness = await _pumpScreen(tester);
      harness.assistantRepository.reply = const AssistantReply(
        text: '* hi',
        proposals: [],
      );
      await _sendText(tester, '記一筆');
      await tester.pumpAndSettle();

      final bubbleWidth = tester
          .getSize(find.ancestor(
            of: find.text('•'),
            matching: find.byType(Container),
          ).first)
          .width;

      // 560 mirrors assistant_screen.dart's private `_bubbleMaxWidth` (not
      // importable here); the point of this test is that the bubble is far
      // under it, not the exact cap.
      expect(bubbleWidth, lessThan(560 / 2));
    });
  });
}
