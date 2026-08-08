import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/assistant/gemini_key_controller.dart';
import '../../../shared/auth/id_token_provider.dart';
import '../domain/assistant_failure.dart';
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

  const AssistantScreen({
    super.key,
    required this.controller,
    required this.geminiKeyController,
    required this.idToken,
    required this.onSignInAgain,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _composer = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.geminiKeyController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.geminiKeyController.removeListener(_onChanged);
    _composer.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    // Read at the moment of sending — the key may have been replaced on the
    // settings page since the last message — and passed straight through;
    // never stored on this State.
    final key = widget.geminiKeyController.key;
    if (key == null) return;
    _composer.clear();
    await widget.controller.send(await widget.idToken(), key, text);
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

  Widget _transcript(BuildContext context, AppLocalizations loc) {
    final theme = Theme.of(context);
    final entries = widget.controller.entries;
    if (entries.isEmpty && widget.controller.status == AssistantStatus.idle) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              loc.assistantEmptyHint,
              key: const Key('assistant-empty-hint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    final rows = <Widget>[
      for (var i = 0; i < entries.length; i++) _entryRow(theme, entries[i], i),
      if (widget.controller.lastError != null) _errorRow(context, loc),
      if (widget.controller.status == AssistantStatus.sending)
        const Padding(
          key: Key('assistant-sending-indicator'),
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
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
            child: Text(entry.text),
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
                constraints: const BoxConstraints(maxWidth: 560),
                child: bubble,
              ),
            ),
          for (var p = 0; p < entry.proposals.length; p++)
            ProposalCard(
              state: entry.proposals[p],
              entryIndex: entryIndex,
              proposalIndex: p,
              onAccept: () => _accept(entryIndex, p),
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
