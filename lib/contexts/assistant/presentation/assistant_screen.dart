import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/assistant/gemini_key_controller.dart';
import '../../../shared/auth/id_token_provider.dart';
import '../domain/assistant_failure.dart';
import 'assistant_chat_context.dart';
import 'assistant_controller.dart';
import 'proposal_card.dart';

/// The assistant conversation: transcript, confirmation cards, composer.
///
/// **Key discipline.** The full Gemini key is read off [GeminiKeyController]
/// only inside [_send]/[_retry], at the moment the request goes out, and is
/// passed straight into the controller call — it lives in no field, no
/// widget state, and nothing here ever renders it.
///
/// **Live key gate.** This screen *listens* to [GeminiKeyController] rather
/// than reading `hasKey` once at build-time capture: the setup state's whole
/// exit is "go to settings, paste a key, come back", and on return the
/// composer must be alive without remounting the screen.
class AssistantScreen extends StatefulWidget {
  final AssistantController controller;
  final GeminiKeyController geminiKeyController;
  final IdTokenProvider idToken;

  /// The standard re-auth exit (sign out, land on the login screen).
  final VoidCallback onSignInAgain;

  /// What the user was looking at when they entered (`null` from the home
  /// grid). Drawn as the transcript's top row and prepended into the first
  /// message's content — **both via [AssistantChatContext.label]**, the one
  /// function, so the model can never be told a view the screen didn't show.
  final AssistantChatContext? chatContext;

  const AssistantScreen({
    super.key,
    required this.controller,
    required this.geminiKeyController,
    required this.idToken,
    required this.onSignInAgain,
    this.chatContext,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

/// The widest a transcript item gets. Shared by the message bubbles and the
/// proposal cards so the two never drift apart on a wide window.
const double _bubbleMaxWidth = 560;

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _composer = TextEditingController();

  /// The entry index the context line was prepended into — `null` until the
  /// first send of a context-carrying visit, then fixed forever. Doubles as
  /// [_transcript]'s anchor for *where the context row paints*: the row
  /// must sit with the turn it rode into the wire, not pinned to the top,
  /// or the screen would show "started from X" over a reply actually
  /// written under Y once older history sits above it. Per `State` on
  /// purpose: the conversation controller is app-lifetime, but the context
  /// belongs to this entry (the route keys the screen on its query, so a
  /// new entry with a different context is a fresh `State`).
  int? _contextEntryIndex;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.geminiKeyController.addListener(_onKeyChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.geminiKeyController.removeListener(_onKeyChanged);
    _composer.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// The stored key changed — `GeminiKeyController` only notifies on save or
  /// clear, so this firing means the user really did go and do something.
  ///
  /// If a send had failed because the backend saw no key, that failure is now
  /// stale and must go. It routes the screen to the setup state, which shows
  /// neither the composer nor the retry button — the only two things that
  /// clear an error — so without this the user pastes a valid key, comes
  /// back, and is still told to add one. Forever: the controller is an
  /// app-lifetime singleton, so re-navigating does not help; only signing out
  /// or reloading did.
  ///
  /// Deliberately keyed on the key *changing* rather than on `hasKey`: the
  /// failure means the backend saw no key, which happens while this device
  /// still has one, so clearing on every notification would stop the setup
  /// state from ever appearing.
  void _onKeyChanged() {
    if (widget.geminiKeyController.hasKey) {
      widget.controller.clearMissingKeyError();
    }
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    // Mirrors the composer/send-button gating; also keeps the context-prefix
    // bookkeeping below honest — past this line the controller *will* append
    // the entry, so marking the prefix as consumed cannot lose it.
    if (widget.controller.status == AssistantStatus.sending) return;
    // Read at the moment of sending — the key may have been replaced on the
    // settings page since the last message — and passed straight through;
    // never stored on this State.
    final key = widget.geminiKeyController.key;
    if (key == null) return;
    // The exact string the context row paints — same function, same output
    // (see [AssistantChatContext.label]). Resolved before the awaits below,
    // while the context is still safely usable.
    String? contextPrefix;
    final chatContext = widget.chatContext;
    if (chatContext != null && _contextEntryIndex == null) {
      contextPrefix = chatContext.label(context);
      // Before the controller appends below — this is the index the new
      // user entry will land on.
      _contextEntryIndex = widget.controller.entries.length;
    }
    _composer.clear();
    await widget.controller.send(
      await widget.idToken(),
      key,
      text,
      contextPrefix: contextPrefix,
    );
  }

  Future<void> _retry() async {
    final key = widget.geminiKeyController.key;
    if (key == null) return;
    await widget.controller.retryLast(await widget.idToken(), key);
  }

  Future<void> _accept(int entryIndex, int proposalIndex) async {
    await widget.controller.accept(
      await widget.idToken(),
      entryIndex,
      proposalIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.assistantTitle)),
      body: SafeArea(child: _body(context, loc)),
    );
  }

  Widget _body(BuildContext context, AppLocalizations loc) {
    final controller = widget.controller;
    if (controller.needsReauth) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('assistant-sign-in-again-button'),
                onPressed: widget.onSignInAgain,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        ),
      );
    }
    // No key stored — or the backend answered "no key reached me" (the key
    // was cleared from another tab after this one's gate check): the setup
    // state, with the way forward. The entry point never hides or greys out.
    if (!widget.geminiKeyController.hasKey ||
        controller.lastError == AssistantFailure.missingKey) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              key: const Key('assistant-setup'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.assistantSetupIntro, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('assistant-setup-settings-button'),
                  onPressed: () => context.push('/settings'),
                  child: Text(loc.assistantGoToSettings),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // The error row lives INSIDE the scrollable transcript (as the newest
    // row), not as a fixed band above the composer: at textScale 2.0 on a
    // 320dp phone a fixed multi-line error plus the composer is taller than
    // the screen and overflows — in the list it scrolls like everything else.
    return Column(
      children: [
        Expanded(child: _transcript(context, loc)),
        _composerRow(context, loc),
      ],
    );
  }

  /// The context row — a system-styled line, visually neither party's
  /// bubble. Its text is [AssistantChatContext.label]'s output, the same
  /// string [_send] prepends into the first message (never composed twice).
  Widget _contextRow(BuildContext context, ThemeData theme) {
    return Container(
      key: const Key('assistant-context-row'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.chatContext!.label(context),
        key: const Key('assistant-context-row-text'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _transcript(BuildContext context, AppLocalizations loc) {
    final theme = Theme.of(context);
    final entries = widget.controller.entries;
    if (entries.isEmpty && widget.controller.status == AssistantStatus.idle) {
      final hint = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              // Keyed on the *month*, not on having a context at all: what
              // this hint is for is a vague "how much did I spend" having
              // nothing to anchor to. The home screen sends no context, and
              // the split tab sends a tab but never a month (`fromQuery`
              // drops it — split has no month to show), so both leave the
              // question unanchored and both need the nudge.
              widget.chatContext?.month == null
                  ? loc.assistantEmptyHintNoContext
                  : loc.assistantEmptyHint,
              key: const Key('assistant-empty-hint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      if (widget.chatContext == null) return hint;
      // The context must be visible *before* the first message too — it is
      // exactly the first message it will be woven into.
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _contextRow(context, theme),
          ),
          Expanded(child: hint),
        ],
      );
    }
    // Where the context row paints: the entry it rode into the wire
    // ([_contextEntryIndex]), or — not consumed yet — right after all
    // existing history, closest to the composer, since that is where the
    // next message (the one it will ride into) is about to appear.
    final contextInsertAt = _contextEntryIndex ?? entries.length;
    final rows = <Widget>[
      for (var i = 0; i < entries.length; i++) ...[
        if (widget.chatContext != null && i == contextInsertAt)
          _contextRow(context, theme),
        _entryRow(theme, entries[i], i),
      ],
      if (widget.chatContext != null && contextInsertAt >= entries.length)
        _contextRow(context, theme),
      if (widget.controller.lastError != null) _errorRow(context, loc),
      if (widget.controller.status == AssistantStatus.sending)
        Padding(
          key: const Key('assistant-sending-indicator'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            // The spinner is animation and nothing else, so a screen-reader
            // user gets no signal at all that a reply is on its way.
            // `liveRegion` makes it an announcement when it appears rather
            // than something you have to go looking for (WCAG 4.1.3).
            child: Semantics(
              label: loc.assistantSendingLabel,
              liveRegion: true,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
    ];
    // `reverse: true` with reversed rows keeps the view pinned to the newest
    // message — including while the keyboard is up — with no scroll-jumping
    // code.
    return ListView(
      key: const Key('assistant-transcript'),
      reverse: true,
      padding: const EdgeInsets.all(16),
      children: rows.reversed.toList(),
    );
  }

  Widget _entryRow(ThemeData theme, AssistantEntry entry, int entryIndex) {
    final isUser = entry.role == 'user';
    final bubble = entry.text.trim().isEmpty
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline, width: 2),
            ),
            // Paired with the background above. A bubble on
            // `primaryContainer` whose text falls through to `onSurface` is
            // 1.4:1 in the dark theme — the user's own words, unreadable.
            // `tracker_day_nav_header.dart` is the house pattern for this.
            child: Text(
              entry.text,
              style: TextStyle(
                color: isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (bubble != null)
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              // Cap the bubble, don't let a long message span edge to edge.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _bubbleMaxWidth),
                child: bubble,
              ),
            ),
          for (var p = 0; p < entry.proposals.length; p++)
            // The same cap as the bubbles above. Two card-shaped things in
            // one transcript growing to different widths on a desktop reads
            // as two unrelated components.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _bubbleMaxWidth),
              child: ProposalCard(
                state: entry.proposals[p],
                entryIndex: entryIndex,
                proposalIndex: p,
                onAccept: () => _accept(entryIndex, p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorRow(BuildContext context, AppLocalizations loc) {
    final theme = Theme.of(context);
    final failure = widget.controller.lastError!;
    final message = switch (failure) {
      AssistantFailure.keyRejected => loc.assistantErrorKeyRejected,
      AssistantFailure.quotaExhausted => loc.assistantErrorQuotaExhausted,
      AssistantFailure.modelUnavailable => loc.assistantErrorModelUnavailable,
      AssistantFailure.serviceUnavailable ||
      AssistantFailure.network =>
        loc.assistantErrorUnavailable,
      // Handled by the setup state in [_body]; unreachable here.
      AssistantFailure.missingKey => loc.assistantErrorUnavailable,
    };
    // Only the failures whose fix lives on the settings page point there —
    // an exhausted quota or a 502 with a settings button would send the user
    // to fiddle with a key that is fine.
    final pointsToSettings = failure == AssistantFailure.keyRejected ||
        failure == AssistantFailure.modelUnavailable;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            key: const Key('assistant-error-text'),
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const Key('assistant-retry-button'),
                onPressed: _retry,
                child: Text(loc.retry),
              ),
              if (pointsToSettings)
                TextButton(
                  key: const Key('assistant-error-settings-button'),
                  onPressed: () => context.push('/settings'),
                  child: Text(loc.assistantGoToSettings),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composerRow(BuildContext context, AppLocalizations loc) {
    final sending = widget.controller.status == AssistantStatus.sending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // A multi-line field swallows Enter: `onSubmitted` fires for a
            // single-line one and for the on-screen keyboard's send action,
            // but on a desktop or the web Enter just inserts a newline and
            // the message sits there. Shift+Enter keeps the newline, which is
            // the convention every chat box on that platform uses.
            child: Focus(
              // Observes keys on their way up from the field; never a stop of
              // its own. Left focusable, this wrapper becomes a separate tab
              // target with no visible focus and no text entry — a
              // keyboard-only user tabs to the composer, types, and nothing
              // appears until they press Tab again.
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
                if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
                // Mid-composition, Enter confirms the candidate — it is how
                // every Chinese and Japanese input method commits a word.
                // Treating it as send fires off the half-composed text *and*
                // eats the confirmation, because the embedder only forwards a
                // key the framework left alone. zh-Hant is this app's other
                // locale; this is not an edge case here.
                if (_composer.value.composing.isValid) return KeyEventResult.ignored;
                _send();
                return KeyEventResult.handled;
              },
              child: TextField(
                key: const Key('assistant-composer-field'),
                controller: _composer,
                enabled: !sending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: loc.assistantComposerHint),
              ),
            ),
          ),
          IconButton(
            key: const Key('assistant-send-button'),
            tooltip: loc.assistantSendTooltip,
            onPressed: sending ? null : _send,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
