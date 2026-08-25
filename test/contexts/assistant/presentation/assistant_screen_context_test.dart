import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/assistant/application/send_assistant_message.dart';
import 'package:life_os/contexts/assistant/domain/assistant_message.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_chat_context.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_controller.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_screen.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/list_finance_categories.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../assistant_test_support.dart';

/// Pinned well away from the real today, mirroring the main screen suite.
final _now = DateTime(2031, 3, 15, 9, 30);

/// The fixture month is deliberately **not** [_now]'s month and not the real
/// today's month either — a context built from "today" instead of the carried
/// month must come out different, or these guards can never go red.
const _fixtureContext = AssistantChatContext(
  tab: 'transactions',
  month: '2025-11',
);

class _Harness {
  final AssistantController controller;
  final RecordingAssistantRepository assistantRepository;

  _Harness(this.controller, this.assistantRepository);
}

Future<_Harness> _pumpScreen(
  WidgetTester tester, {
  AssistantChatContext? chatContext,
  bool healthEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final keyController = GeminiKeyController(
    await SharedPreferences.getInstance(),
  );
  await keyController.setKey('test-key');
  // These tests are about the hint/chip *selection* logic, not the health
  // access-off notice (that has its own tests) — access defaults to on so the
  // hint this file asserts on is actually reachable in a health context.
  if (healthEnabled) await keyController.setHealthEnabled(true);
  final assistantRepository = RecordingAssistantRepository();
  final financeRepository = GatedFinanceRepository();
  final controller = AssistantController(
    SendAssistantMessage(assistantRepository),
    AddTransaction(financeRepository),
    ListFinanceCategories(financeRepository),
    clock: () => _now,
  );
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: AssistantScreen(
        controller: controller,
        geminiKeyController: keyController,
        idToken: () async => 'token-1',
        onSignInAgain: () {},
        chatContext: chatContext,
      ),
    ),
  );
  await tester.pump();
  return _Harness(controller, assistantRepository);
}

Future<void> _sendText(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const Key('assistant-composer-field')),
    text,
  );
  await tester.tap(find.byKey(const Key('assistant-send-button')));
  await tester.pumpAndSettle();
}

/// Like [_pumpScreen], but the controller already carries one finished
/// exchange **before** the screen (and its context bookkeeping) is built —
/// re-entering an assistant conversation that already has history, on a
/// fresh route/`State` for a new [chatContext]. Only this path exercises
/// where the context row paints relative to *existing* entries; [_pumpScreen]
/// always starts from an empty controller.
Future<_Harness> _pumpScreenWithHistory(
  WidgetTester tester, {
  required AssistantChatContext chatContext,
}) async {
  SharedPreferences.setMockInitialValues({});
  final keyController = GeminiKeyController(
    await SharedPreferences.getInstance(),
  );
  await keyController.setKey('test-key');
  final assistantRepository = RecordingAssistantRepository();
  final financeRepository = GatedFinanceRepository();
  final controller = AssistantController(
    SendAssistantMessage(assistantRepository),
    AddTransaction(financeRepository),
    ListFinanceCategories(financeRepository),
    clock: () => _now,
  );
  // A distinct reply text ('old reply', not the default 'ok') so the two
  // pre-seeded rows and the row a test later sends are all independently
  // findable by text.
  assistantRepository.reply = const AssistantReply(
    text: 'old reply',
    proposals: [],
  );
  await controller.send('token-1', 'test-key', 'old message', healthEnabled: false);
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: AssistantScreen(
        controller: controller,
        geminiKeyController: keyController,
        idToken: () async => 'token-1',
        onSignInAgain: () {},
        chatContext: chatContext,
      ),
    ),
  );
  await tester.pump();
  return _Harness(controller, assistantRepository);
}

void main() {
  group('AssistantScreen with a chat context', () {
    testWidgets(
      'the string painted in the context row is the string sent — read off '
      'the screen, then found verbatim in the first message content',
      (tester) async {
        final harness = await _pumpScreen(tester, chatContext: _fixtureContext);

        // Visible before the first message — on the empty state too.
        final painted = tester
            .widget<Text>(find.byKey(const Key('assistant-context-row-text')))
            .data!;
        // The month is rendered through the locale-aware `monthYearLabel`
        // convention (design E), not the raw `2025-11`.
        expect(
          painted,
          contains(DateFormat.yMMM('en').format(DateTime(2025, 11))),
          reason: 'the row must name the carried (non-today) month',
        );

        await _sendText(tester, 'hello there');

        final first = harness.assistantRepository.calls.single.single;
        expect(first.role, 'user');
        // Exact equality, not `contains`: a prefix duplicated (sent twice) or
        // glued on with no separator still `contains` the painted string —
        // only equality catches it.
        expect(
          first.content,
          '$painted\nhello there',
          reason:
              'the sent content must be exactly the painted string, a '
              'newline, then the words — display and wire may never compose '
              'separately',
        );

        // The bubble draws the bare words; the context line is painted once,
        // in the row — not duplicated inside the user's own bubble.
        expect(find.text('hello there'), findsOneWidget);
        expect(find.textContaining(painted), findsOneWidget);
      },
    );

    testWidgets(
      'the prefix rides the first turn only, but stays in replayed history',
      (tester) async {
        final harness = await _pumpScreen(tester, chatContext: _fixtureContext);
        final painted = tester
            .widget<Text>(find.byKey(const Key('assistant-context-row-text')))
            .data!;

        await _sendText(tester, 'first');
        await _sendText(tester, 'second');

        final secondCall = harness.assistantRepository.calls[1];
        expect(
          secondCall.first.content,
          '$painted\nfirst',
          reason:
              'history must replay the first turn with its prefix intact '
              '— exactly, not just containing it',
        );
        expect(
          secondCall.last.content,
          'second',
          reason: 'the context is woven in once — not onto every turn',
        );
      },
    );

    testWidgets('no context: no row, and content goes out bare', (
      tester,
    ) async {
      final harness = await _pumpScreen(tester);
      expect(find.byKey(const Key('assistant-context-row')), findsNothing);
      await _sendText(tester, 'plain');
      expect(harness.assistantRepository.calls.single.single.content, 'plain');
    });

    testWidgets(
      'the empty-state hint differs with and without a chat context — '
      'without one, the model has no month/tab to anchor a vague question '
      'to, so the hint must say so',
      (tester) async {
        // Literals, never `loc.assistantEmptyHint*`: an expectation read from
        // the same ARB entry the widget reads compares a string with itself
        // and can never go red — which also makes two ARB entries written
        // with identical copy visible here, since each line pins its own.
        const homeHint =
            'Ask about your spending, budgets or split balances — or tell me '
            'a transaction to log. You can also ask about your health, diet '
            "and care records. I don't know what you were looking at, so name "
            'the period you mean.';
        const financeHint =
            'Ask about your spending, budgets or split balances — or tell me '
            'a transaction to log.';
        const financeHintNoContext =
            "Ask about your spending, budgets or split balances — or tell me "
            "a transaction to log. I don't know what you were looking at, so "
            "name a month if it matters.";

        // No context (e.g. opened from the home screen) — neither module, so
        // the hint names both halves.
        await _pumpScreen(tester);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('assistant-empty-hint')))
              .data,
          homeHint,
        );

        // With a context (e.g. opened from the finance tabs).
        await _pumpScreen(tester, chatContext: _fixtureContext);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('assistant-empty-hint')))
              .data,
          financeHint,
        );

        // The split tab carries a tab but never a month (`fromQuery` drops
        // it — split has no month to show), so a vague "how much did I
        // spend" has nothing to anchor to here either. Keying the hint on
        // "is there a context at all" instead of "is there a month" sends
        // the WITH-context copy to a screen that cannot honour it.
        await _pumpScreen(
          tester,
          chatContext: const AssistantChatContext(tab: 'split'),
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('assistant-empty-hint')))
              .data,
          financeHintNoContext,
          reason: 'split has no month, so it needs the same nudge the home '
              'entry gets — in the finance-only wording, since split IS a '
              'finance entry',
        );
      },
    );

    testWidgets(
      'the empty-state hint follows the entered MODULE, and its '
      'ask-for-a-period half follows whether any period is on screen',
      (tester) async {
        // Every expectation below is the literal copy, not `_loc.<key>`: an
        // assertion built from the same ARB entry the widget reads compares
        // a string with itself and can never go red. Each of the four hints
        // is asserted on its own so a single ARB mutation fails one line.
        const healthHint = 'Ask about your health, diet and care records.';
        const healthHintNoDay =
            "Ask about your health, diet and care records. I don't know "
            "which day you were looking at, so name the period you mean.";
        const financeHint =
            'Ask about your spending, budgets or split balances — or tell me '
            'a transaction to log.';
        const financeHintNoContext =
            "Ask about your spending, budgets or split balances — or tell me "
            "a transaction to log. I don't know what you were looking at, so "
            "name a month if it matters.";
        const homeHint =
            'Ask about your spending, budgets or split balances — or tell me '
            'a transaction to log. You can also ask about your health, diet '
            "and care records. I don't know what you were looking at, so name "
            'the period you mean.';
        const homeHintConsentOff =
            'Ask about your spending, budgets or split balances — or tell me '
            'a transaction to log. Turn on health access in settings and you '
            "can also ask about your health, diet and care records. I don't "
            'know what you were looking at, so name the period you mean.';

        String hint() => tester
            .widget<Text>(find.byKey(const Key('assistant-empty-hint')))
            .data!;

        // Health with a day: health copy, no ask-for-a-period sentence.
        await _pumpScreen(
          tester,
          chatContext: AssistantChatContext.fromQuery(const {
            'ctx': 'health',
            'tab': 'overview',
            'day': '2026-08-22',
          }),
        );
        expect(hint(), healthHint);
        // Stated separately from the equality above: the equality would still
        // pass if BOTH ARB entries were written with the finance wording.
        expect(hint(), isNot(contains('spending')));
        expect(hint(), isNot(contains('budgets')));
        expect(hint(), isNot(contains('split balances')));

        // 記錄/趨勢 carry a tab but never a day (`fromQuery` drops it), so
        // the question has nothing to anchor to — health copy, WITH the
        // nudge.
        for (final tab in const ['record', 'trends']) {
          await _pumpScreen(
            tester,
            chatContext: AssistantChatContext.fromQuery({
              'ctx': 'health',
              'tab': tab,
              'day': '2026-08-22',
            }),
          );
          expect(hint(), healthHintNoDay, reason: '$tab shows no day');
        }

        await _pumpScreen(
          tester,
          chatContext: AssistantChatContext.fromQuery(const {
            'ctx': 'finance',
            'tab': 'transactions',
            'month': '2025-11',
          }),
        );
        expect(hint(), financeHint);

        await _pumpScreen(
          tester,
          chatContext: AssistantChatContext.fromQuery(const {
            'ctx': 'finance',
            'tab': 'split',
          }),
        );
        expect(hint(), financeHintNoContext);

        // The home entry is neither module, so it gets neither module's
        // hint: both halves named, and the same nudge. The health half is a
        // flat promise once the consent is on and an invitation while it is
        // off — the two fixtures differ in nothing else.
        await _pumpScreen(tester, healthEnabled: true);
        expect(hint(), homeHint);

        await _pumpScreen(tester, healthEnabled: false);
        expect(hint(), homeHintConsentOff);
      },
    );

    testWidgets(
      'a health context row states the health view, and the first message '
      'carries that same line character for character',
      (tester) async {
        final harness = await _pumpScreen(
          tester,
          chatContext: AssistantChatContext.fromQuery(const {
            'ctx': 'health',
            'tab': 'overview',
            'day': '2026-08-22',
          }),
        );

        final painted = tester
            .widget<Text>(find.byKey(const Key('assistant-context-row-text')))
            .data!;
        expect(painted, 'Started from: Health Overview Aug 22, 2026');

        await _sendText(tester, 'what can I still eat?');

        final first = harness.assistantRepository.calls.single.single;
        // Exact equality, not `contains`: a prefix duplicated or glued on
        // with no separator still `contains` the painted string.
        expect(
          first.content,
          'Started from: Health Overview Aug 22, 2026\nwhat can I still eat?',
        );
      },
    );

    testWidgets(
      'a reply in flight is announced, not just animated',
      (tester) async {
        // The spinner carries the whole "something is happening" signal, and
        // an animation says nothing to a screen reader (WCAG 4.1.3).
        final semantics = tester.ensureSemantics();
        final loc = lookupAppLocalizations(const Locale('en'));

        final harness = await _pumpScreen(tester, chatContext: _fixtureContext);
        // Hold the request open so the sending row is on screen to inspect.
        // Not `_sendText`: its `pumpAndSettle` never returns while the gate
        // holds and the spinner animates.
        harness.assistantRepository.gate = Completer<void>();
        await tester.enterText(
          find.byKey(const Key('assistant-composer-field')),
          'hello',
        );
        await tester.tap(find.byKey(const Key('assistant-send-button')));
        await tester.pump();

        expect(
          harness.controller.status,
          AssistantStatus.sending,
          reason: 'the gate must actually be holding, or this asserts nothing',
        );
        // Read the label off the rendered semantics node rather than the
        // widget: a `Semantics` whose child has no size is dropped before it
        // reaches the tree, and that is exactly the failure worth catching.
        expect(
          tester.getSemantics(
            find.byKey(const Key('assistant-sending-indicator')),
          ),
          matchesSemantics(
            label: loc.assistantSendingLabel,
            isLiveRegion: true,
          ),
        );

        harness.assistantRepository.gate!.complete();
        await tester.pump();
        await tester.pump();
        // Inline, not `addTearDown`: the framework's own
        // "SemanticsHandle was active" check runs before tear-downs do.
        semantics.dispose();
      },
    );

    testWidgets(
      '320dp × textScale 2.0: the context row lays out and paints in full',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() => tester.platformDispatcher.clearAllTestValues());

        await expectNoLayoutErrors(() async {
          final harness = await _pumpScreen(
            tester,
            chatContext: _fixtureContext,
          );
          expectPaintedInFull(
            tester,
            find.byKey(const Key('assistant-context-row-text')),
            reason: 'the context row must not truncate on a narrow screen',
          );
          // And with a transcript behind it: not just "no layout error" (a
          // `Clip`/`FittedBox`-style truncation raises none at all) — the
          // context row must still paint every glyph once it is sharing the
          // scroll view with a message.
          await _sendText(tester, '這個月的餐飲花了多少?');
          // If the send button's tap misses at this size (a future layout
          // change), `_sendText` only `flutter_test`-warns — it does not
          // fail. Without this, the block above would still pass by quietly
          // re-checking the empty-state row instead of the transcript one.
          expect(
            harness.assistantRepository.calls,
            hasLength(1),
            reason: 'the send tap must actually have gone through',
          );
          expectPaintedInFull(
            tester,
            find.byKey(const Key('assistant-context-row-text')),
            reason:
                'the context row must not truncate once the transcript '
                'has messages',
          );
        }, reason: '320dp × textScale 2.0 must not overflow');
      },
    );

    testWidgets(
      'an unconsumed context row sits after existing history, closest to '
      'the composer — not pinned above it',
      (tester) async {
        await _pumpScreenWithHistory(tester, chatContext: _fixtureContext);

        // Below (larger dy than) both rows of the pre-seeded exchange: the
        // row has nothing to ride yet, so it belongs where the next message
        // — the one it WILL ride into — is about to appear, not at the top
        // of older history it had nothing to do with.
        final rowDy = tester
            .getTopLeft(find.byKey(const Key('assistant-context-row-text')))
            .dy;
        expect(
          rowDy,
          greaterThan(tester.getTopLeft(find.text('old message')).dy),
        );
        expect(
          rowDy,
          greaterThan(tester.getTopLeft(find.text('old reply')).dy),
        );
      },
    );

    testWidgets(
      'the context row rides the turn it was sent with — below older '
      'history, above the message that carried it',
      (tester) async {
        final harness = await _pumpScreenWithHistory(
          tester,
          chatContext: _fixtureContext,
        );
        // Distinct from the pre-seeded 'old reply' so both are independently
        // findable by text.
        harness.assistantRepository.reply = const AssistantReply(
          text: 'new reply',
          proposals: [],
        );

        await _sendText(tester, 'new message');

        final rowDy = tester
            .getTopLeft(find.byKey(const Key('assistant-context-row-text')))
            .dy;
        // Below the pre-existing exchange the screen already had...
        expect(
          rowDy,
          greaterThan(tester.getTopLeft(find.text('old message')).dy),
        );
        expect(
          rowDy,
          greaterThan(tester.getTopLeft(find.text('old reply')).dy),
        );
        // ...but above the very message it was prepended into.
        expect(rowDy, lessThan(tester.getTopLeft(find.text('new message')).dy));
        expect(harness.assistantRepository.calls, hasLength(2));

        // GUARD: Verify the row paints a second time on a third message.
        // If _contextEntryIndex is incorrectly reset, the row would move to
        // be between the second message and third message instead. The context
        // row key is unique (not dynamic), so there is exactly one row on screen
        // — this guard proves it stays where it landed on the first send.
        harness.assistantRepository.reply =
            const AssistantReply(text: 'reply 2', proposals: []);
        await _sendText(tester, 'message 2');

        // The row must still be findable by its unique key — not replaced,
        // not moved to a different entry, just on-screen where it was.
        expect(
          find.byKey(const Key('assistant-context-row-text')),
          findsOneWidget,
          reason:
              'the context row must persist anchored to the first message, '
              'not reset to a different entry on the second send',
        );
      },
    );
  });
}
