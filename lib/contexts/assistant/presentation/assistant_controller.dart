import 'package:flutter/foundation.dart';

import '../../../shared/date/day_format.dart';
import '../../finance/application/add_transaction.dart';
import '../../finance/application/list_finance_categories.dart';
import '../../finance/domain/finance_category.dart';
import '../../finance/domain/finance_exceptions.dart';
import '../application/send_assistant_message.dart';
import '../domain/assistant_failure.dart';
import '../domain/assistant_message.dart';
import '../domain/transaction_draft.dart';

/// Whether a send is in flight (the composer and retry are gated on it).
enum AssistantStatus { idle, sending }

/// One confirmation card's lifecycle. `pending → saving → saved` on the happy
/// path. `failed` and `categoryNotFound` both keep the accept button live:
/// the first because a retry may succeed, the second because its message
/// sends the user off to create the category and pressing again on their
/// return has to re-resolve it. Refusing to write into a wrong category is
/// the honest part; making the fix unusable was not.
enum ProposalStatus { pending, saving, saved, failed, categoryNotFound }

/// The state of one proposal card. [draft] is `null` for a proposal
/// [TransactionDraft.fromProposal] refused to normalize — rendered as an
/// unusable card with no accept button, never as a blank the user might
/// accept.
class ProposalState {
  final TransactionDraft? draft;

  ProposalStatus status = ProposalStatus.pending;

  ProposalState(this.draft);
}

/// One transcript row: the user's message, or the assistant's reply with its
/// proposal cards.
class AssistantEntry {
  final String role;

  /// What the transcript draws for this turn — the user's words alone.
  final String text;

  /// What goes on the wire for this turn: [text], with the screen's context
  /// line prepended on the one entry that introduced it. The backend body is
  /// `{messages}` only — no context field — so the context can only travel
  /// inside content. Stored on the entry (not re-derived per send) so a
  /// retry or any later send replays the identical history.
  final String wireContent;

  final List<ProposalState> proposals;

  AssistantEntry.user(this.text, {String? contextPrefix})
      : role = 'user',
        wireContent = contextPrefix == null ? text : '$contextPrefix\n$text',
        proposals = const [];

  AssistantEntry.assistant(this.text, this.proposals)
      : role = 'assistant',
        wireContent = text;
}

/// Holds the assistant conversation — **in memory only, for the app's
/// lifetime**. Deliberately not persisted: the backend refuses to store these
/// conversations (they are the user's financial life in prose) and writing
/// them to device storage is the same problem in a different place; worse, a
/// persisted proposal card replayed the next day would still carry
/// yesterday's `day`. Being an app-lifetime singleton already covers the real
/// need (check the ledger, come back, the conversation is still there) — and
/// therefore this MUST be in `app.dart`'s sign-out reset list, or the next
/// account on this device reads the previous account's finances.
///
/// The Gemini key is **not** state here: every send takes it as a parameter,
/// read from `GeminiKeyController` at the moment of sending, and nothing in
/// this class retains it past the awaited call.
class AssistantController extends ChangeNotifier {
  final SendAssistantMessage _sendMessage;
  final AddTransaction _addTransaction;
  final ListFinanceCategories _listCategories;
  final DateTime Function() _clock;

  AssistantController(
    this._sendMessage,
    this._addTransaction,
    this._listCategories, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  final List<AssistantEntry> _entries = [];

  List<AssistantEntry> get entries => List.unmodifiable(_entries);

  AssistantStatus _status = AssistantStatus.idle;
  AssistantStatus get status => _status;

  /// The failure of the **last** send, `null` after a success or a reset. The
  /// failed user message stays in [entries]; retry re-sends the same history.
  AssistantFailure? _lastError;
  AssistantFailure? get lastError => _lastError;

  /// Set when any request came back 401 — the screen shows the app's
  /// standard sign-in-again exit.
  bool _needsReauth = false;
  bool get needsReauth => _needsReauth;

  /// Appends [text] as a user turn and asks for the next reply. [geminiKey]
  /// is used for this one request and not retained.
  ///
  /// [contextPrefix] — the screen's context line ("進入時檢視:…"), prepended
  /// into this turn's **wire content only** (the transcript keeps drawing
  /// [text]; the context is drawn once as its own row). The screen passes it
  /// on the first send of a context-carrying visit.
  Future<void> send(
    String idToken,
    String geminiKey,
    String text, {
    String? contextPrefix,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _status == AssistantStatus.sending) return;
    _entries.add(AssistantEntry.user(trimmed, contextPrefix: contextPrefix));
    _lastError = null;
    await _dispatch(idToken, geminiKey);
  }

  /// Re-sends the history exactly as it stands after a failed send — no new
  /// user entry is appended, so retrying can never duplicate the message.
  Future<void> retryLast(String idToken, String geminiKey) async {
    if (_status == AssistantStatus.sending || _lastError == null) return;
    _lastError = null;
    await _dispatch(idToken, geminiKey);
  }

  Future<void> _dispatch(String idToken, String geminiKey) async {
    _status = AssistantStatus.sending;
    notifyListeners();
    try {
      final reply = await _sendMessage(
        idToken,
        geminiKey: geminiKey,
        messages: _messages(),
      );
      // The fallback day is resolved when the reply *arrives* — this is the
      // "today" any dayless proposal on it will be saved under.
      final today = dayString(_clock());
      _entries.add(
        AssistantEntry.assistant(reply.text, [
          for (final proposal in reply.proposals)
            ProposalState(
              TransactionDraft.fromProposal(proposal, fallbackDay: today),
            ),
        ]),
      );
    } on AssistantReauthRequired {
      _needsReauth = true;
    } on AssistantSendFailure catch (failure) {
      _lastError = failure.failure;
    } catch (_) {
      _lastError = AssistantFailure.network;
    } finally {
      _status = AssistantStatus.idle;
      notifyListeners();
    }
  }

  /// The full history as wire messages. Empty-text turns (an assistant reply
  /// that was proposals-only) are skipped: the backend rejects empty content
  /// outright.
  List<AssistantMessage> _messages() => [
    for (final entry in _entries)
      if (entry.text.trim().isNotEmpty)
        AssistantMessage(role: entry.role, content: entry.wireContent),
  ];

  /// Accepts one proposal card: resolves the category by name against the
  /// user's live list and saves **the card's own draft** through the existing
  /// `AddTransaction` — rendering and writing never interpret the proposal
  /// separately.
  ///
  /// Reentrancy: only `pending` and `failed` cards may enter (the UI also
  /// disables the button while `saving` — this guard is the second lock), so
  /// a double tap or a stray direct call can never record twice.
  Future<void> accept(String idToken, int entryIndex, int proposalIndex) async {
    if (entryIndex < 0 || entryIndex >= _entries.length) return;
    final proposals = _entries[entryIndex].proposals;
    if (proposalIndex < 0 || proposalIndex >= proposals.length) return;
    final proposal = proposals[proposalIndex];
    final draft = proposal.draft;
    if (draft == null) return;
    // `categoryNotFound` is re-enterable, and that is the whole point of the
    // copy: it tells the user to go and create the category, so coming back
    // and pressing again has to re-resolve it. A terminal state here would
    // make the instruction a lie — they would have to retype the request to
    // get a fresh card. `saving` and `saved` stay closed.
    if (proposal.status != ProposalStatus.pending &&
        proposal.status != ProposalStatus.failed &&
        proposal.status != ProposalStatus.categoryNotFound) {
      return;
    }
    proposal.status = ProposalStatus.saving;
    notifyListeners();
    try {
      final match = _matchCategory(await _listCategories(idToken), draft);
      if (match == null) {
        proposal.status = ProposalStatus.categoryNotFound;
        return;
      }
      await _addTransaction(
        idToken,
        type: draft.type,
        amount: draft.amount,
        currency: draft.currency,
        categoryId: match.id,
        date: draft.day,
        note: draft.note,
      );
      proposal.status = ProposalStatus.saved;
    } on FinanceReauthenticationRequired {
      // Back to pending, not failed: the card itself is fine — the session
      // is not, and the whole screen switches to the re-auth exit.
      proposal.status = ProposalStatus.pending;
      _needsReauth = true;
    } catch (_) {
      proposal.status = ProposalStatus.failed;
    } finally {
      notifyListeners();
    }
  }

  /// Exact, case-insensitive name match among the user's **active**
  /// categories of the draft's own type. `null` (no name, or no match) is an
  /// honest dead end — never a guess.
  FinanceCategory? _matchCategory(
    List<FinanceCategory> categories,
    TransactionDraft draft,
  ) {
    final name = draft.categoryName?.toLowerCase();
    if (name == null) return null;
    for (final category in categories) {
      if (!category.archived &&
          category.type == draft.type &&
          category.name.toLowerCase() == name) {
        return category;
      }
    }
    return null;
  }

  /// Clears the conversation — called from `app.dart`'s sign-out reset so
  /// the next account on this device never reads this one's transcript.
  /// Forgets a `missingKey` failure once a key exists again.
  ///
  /// That failure routes the screen to its setup state, which shows neither
  /// the composer nor the retry button — the only two things that clear an
  /// error. Without this the user pastes a valid key, comes back, and is
  /// still told to go and add one, forever: the controller is an app-lifetime
  /// singleton, so re-navigating does not help either. Only sign-out or a
  /// hard reload escaped it.
  ///
  /// Deliberately narrow: any other failure is cleared by retrying, which is
  /// reachable from the transcript.
  void clearMissingKeyError() {
    if (_lastError != AssistantFailure.missingKey) return;
    _lastError = null;
    notifyListeners();
  }

  void reset() {
    _entries.clear();
    _status = AssistantStatus.idle;
    _lastError = null;
    _needsReauth = false;
    notifyListeners();
  }
}
