// lib/features/correspondence/screens/inbox_screen.dart
//
// §3.5 Inbox — case-relevance email triage. Deliberately NOT a mail client:
// no read/unread, folders, or full-text search. It surfaces the most recent
// Gmail messages and lets the surveyor decide, per message, where each one
// belongs:
//   • "Link to case"  — imports the raw email into an existing case's
//     Correspondence register (same importEml pipeline as the Gmail picker,
//     so it gets the identical pending-review / AI-extraction treatment).
//   • "New case"      — jumps to the create-case flow for an email that looks
//     like a fresh instruction.
// Handled messages are greyed out locally so the surveyor can work down the
// list in one pass.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/gmail_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../providers/correspondence_provider.dart';
import '../providers/inbox_provider.dart';
import '../providers/case_inbox_provider.dart';
import '../providers/mail_poll_provider.dart';
import '../utils/correspondence_threads.dart';
import '../widgets/attachment_import.dart';
import '../../../core/utils/eml_parser.dart';
import '../../../shared/widgets/back_app_bar.dart';

const _kColor = Color(0xFF2A6099);

/// Best short label for a case in the picker / snackbar: composite title if
/// set, else vessel name, else the technical file number.
String _caseLabel(CaseModel c) {
  if ((c.title ?? '').trim().isNotEmpty) return c.title!.trim();
  if ((c.vesselName ?? '').trim().isNotEmpty) return c.vesselName!.trim();
  return c.technicalFileNo;
}

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, this.caseId});

  /// When set, the Inbox opens filtered to just this case's relevant, not-yet-
  /// imported mail (16 July 2026 reports). A "Show all" toggle drops back to
  /// the unfiltered whole-inbox triage. Null = the global inbox (Cases list).
  final String? caseId;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  // Gmail message ids the surveyor has already filed this session — greyed
  // out and shown with a "Filed" chip so a long inbox can be worked in one
  // pass without losing your place.
  final Set<String> _handled = {};
  // Message id currently being imported (spinner on its card).
  String? _busyId;
  // Case mode only: false = filtered to this case (default), true = all mail.
  bool _showAll = false;

  // Free-text Gmail search. When non-empty it OVERRIDES both the case filter
  // and the All-mail list — the surveyor's way past a filter that was "too
  // restrictive" (16 & 23 July reports).
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  bool get _searching => _query.trim().isNotEmpty;
  // Case scoping only applies when NOT running a free-text search.
  bool get _caseMode => widget.caseId != null && !_showAll && !_searching;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Opening the Inbox is the surveyor actually looking at their mail —
    // clears the shared §3.14 new-mail badge shown elsewhere (Cases list,
    // Correspondence) so it doesn't keep flagging mail already seen here.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(mailPollProvider.notifier).markSeen());
  }

  /// Groups the flat message list into email trails by normalised subject,
  /// preserving newest-first order (each group's first entry is its newest).
  List<List<GmailMessageSummary>> _groupThreads(
      List<GmailMessageSummary> msgs) {
    final byKey = <String, List<GmailMessageSummary>>{};
    final order = <String>[];
    for (final m in msgs) {
      final norm = normalizeSubjectForThreading(m.subject);
      final key = norm.isEmpty ? 'id:${m.id}' : norm;
      if (!byKey.containsKey(key)) order.add(key);
      byKey.putIfAbsent(key, () => []).add(m);
    }
    return [for (final k in order) byKey[k]!];
  }

  /// Files an entire trail (every message in the group) to a case in one
  /// action, then silently imports the pooled attachments.
  Future<void> _linkThread(List<GmailMessageSummary> group) async {
    CaseModel? selected;
    // In case mode the target is unambiguous — this case — so file directly
    // instead of asking the surveyor to pick it out of a list every time.
    if (widget.caseId != null) {
      selected = ref.read(caseProvider(widget.caseId!)).value;
    }
    selected ??= await showModalBottomSheet<CaseModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CasePickerSheet(),
    );
    if (selected == null || !mounted) return;

    setState(() => _busyId = group.first.id);
    try {
      final notifier =
          ref.read(correspondenceProvider(selected.caseId).notifier);
      final pooled = <EmlAttachment>[];
      final attCorr = <EmlAttachment, String>{};
      for (final msg in group) {
        final bytes = await GmailService.fetchRawMessage(msg.id);
        final (corr, atts) = await notifier.importEml(
          caseId: selected.caseId,
          bytes: bytes,
          filename: '${msg.subject}.eml',
        );
        for (final a in atts) {
          attCorr[a] = corr.id;
        }
        pooled.addAll(atts);
      }
      if (!mounted) return;
      setState(() => _handled.addAll(group.map((m) => m.id)));
      // Silent — attachments are listed on the Correspondence card, no pop-up.
      await autoImportAttachments(
        context,
        ref,
        caseId: selected.caseId,
        attachments: pooled,
        sourceIdFor: (a) => attCorr[a],
      );
      if (!mounted) return;
      final n = group.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Filed ${n > 1 ? '$n messages' : 'email'} to "${_caseLabel(selected)}"'),
          backgroundColor: AppColors.success,
        ),
      );
    } on GoogleSignInCancelled {
      // User backed out of the sign-in — nothing to do.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _startNewCase(GmailMessageSummary msg) {
    // Mark handled so it drops out of the triage pass, then hand off to the
    // existing create-case flow. (Pre-filling the new case from the email's
    // sender/subject is a future enhancement — see TODO §3.5.)
    setState(() => _handled.add(msg.id));
    context.go('/cases/new');
  }

  void _refresh() {
    if (_searching) {
      ref.invalidate(inboxSearchProvider(_query.trim()));
      return;
    }
    if (widget.caseId != null) {
      ref.invalidate(caseInboxRawProvider(widget.caseId!));
    }
    ref.invalidate(inboxMessagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final caseMode = _caseMode;
    final AsyncValue<List<GmailMessageSummary>> async = _searching
        ? ref.watch(inboxSearchProvider(_query.trim()))
        : caseMode
            ? ref.watch(caseInboxProvider(widget.caseId!))
            : ref.watch(inboxMessagesProvider);
    return PopScope(
      canPop: widget.caseId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.caseId != null) {
          context.go('/cases/${widget.caseId}/correspondence');
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Inbox', style: TextStyle(fontSize: 15)),
        // /inbox is a top-level route, so the default fallback would strip to
        // /cases (the case LIST). When opened for a case (from its
        // Correspondence screen), go back there instead of the list.
        backRoute: widget.caseId != null
            ? '/cases/${widget.caseId}/correspondence'
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchCtrl,
            onSubmitted: (v) => setState(() => _query = v),
            onClear: () => setState(() {
              _searchCtrl.clear();
              _query = '';
            }),
          ),
          if (!_searching)
            _TriageBanner(
              caseMode: caseMode,
              showToggle: widget.caseId != null,
              showAll: _showAll,
              onToggle: (v) => setState(() => _showAll = v),
            ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e,
                onRetry: _refresh,
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                        _searching
                            ? 'No mail matches "${_query.trim()}".'
                            : caseMode
                                ? 'No un-filed mail matches this case.'
                                : 'No recent messages.',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                  );
                }
                final threads = _groupThreads(messages);
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: threads.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final group = threads[i];
                    return _MessageCard(
                      msg: group.first, // newest message represents the trail
                      trailCount: group.length,
                      handled: group.every((m) => _handled.contains(m.id)),
                      busy: group.any((m) => _busyId == m.id),
                      // "New case" only makes sense in the global inbox, not
                      // when already scoped to a case (24 July 2026 report).
                      showNewCase: widget.caseId == null,
                      onLink: () => _linkThread(group),
                      onNewCase: () => _startNewCase(group.first),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Free-text Gmail search bar. Submitting runs a full-mailbox Gmail search
/// (sender, subject:, quoted phrases, has:attachment…) that overrides the case
/// filter — the fix for "the inbox filter is too restrictive / not editable".
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search all mail — sender, subject, keyword…',
          hintStyle:
              const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search, size: 18, color: _kColor),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear search',
                    onPressed: onClear,
                  ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kColor),
          ),
        ),
      ),
    );
  }
}

class _TriageBanner extends StatelessWidget {
  const _TriageBanner({
    this.caseMode = false,
    this.showToggle = false,
    this.showAll = false,
    this.onToggle,
  });

  /// Currently showing the case-filtered subset (vs the whole inbox).
  final bool caseMode;

  /// Whether to render the "This case / All mail" toggle at all (only when
  /// the Inbox was opened from a specific case).
  final bool showToggle;
  final bool showAll;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kColor.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.rule_folder_outlined, size: 16, color: _kColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caseMode
                  ? 'Showing mail relevant to this case, not already filed. '
                      'File each one, or switch to all mail.'
                  : 'Triage: file each email to a case, or start a new one. '
                      'This is not a full mailbox.',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
          if (showToggle) ...[
            const SizedBox(width: 6),
            _ScopeToggle(showAll: showAll, onToggle: onToggle),
          ],
        ],
      ),
    );
  }
}

/// Compact segmented "This case / All mail" switch shown in the banner when
/// the Inbox is opened from a specific case.
class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.showAll, required this.onToggle});
  final bool showAll;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8)),
      ),
      segments: const [
        ButtonSegment(value: false, label: Text('This case')),
        ButtonSegment(value: true, label: Text('All mail')),
      ],
      selected: {showAll},
      onSelectionChanged: (s) => onToggle?.call(s.first),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.msg,
    required this.trailCount,
    required this.handled,
    required this.busy,
    required this.showNewCase,
    required this.onLink,
    required this.onNewCase,
  });

  final GmailMessageSummary msg;
  final int trailCount;
  final bool handled;
  final bool busy;
  final bool showNewCase;
  final VoidCallback onLink;
  final VoidCallback onNewCase;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: handled ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    msg.subject,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailCount > 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Trail · $trailCount',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kColor)),
                  ),
                ],
                if (msg.date != null && _shortDate(msg.date!).isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(_shortDate(msg.date!),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(msg.from,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (msg.snippet.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(msg.snippet,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textTertiary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            if (handled)
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  SizedBox(width: 5),
                  Text('Filed',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ],
              )
            else
              Row(
                children: [
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed: onLink,
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Link to case',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: _kColor,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (showNewCase)
                      TextButton.icon(
                        onPressed: onNewCase,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('New case',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _shortDate(String rfc822Date) {
    // Gmail Date headers are RFC-2822 ("Mon, 21 Oct 2025 14:30:00 +1100"),
    // which DateTime.parse can't handle — use the lenient parser.
    final d = EmlParser.parseRfc2822Date(rfc822Date);
    return d == null ? '' : DateFormat('dd MMM').format(d);
  }
}

/// Bottom sheet listing existing cases so the surveyor can pick which one an
/// email belongs to.
class _CasePickerSheet extends ConsumerWidget {
  const _CasePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(casesProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (ctx, scrollCtrl) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('File to which case?',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load cases: $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ),
                data: (cases) {
                  if (cases.isEmpty) {
                    return const Center(
                      child: Text('No cases yet.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    itemCount: cases.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final c = cases[i];
                      return ListTile(
                        title: Text(_caseLabel(c),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [c.technicalFileNo, c.status.label]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cancelled = error is GoogleSignInCancelled;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cancelled ? Icons.mail_lock_outlined : Icons.error_outline,
              size: 52, color: AppColors.coral),
          const SizedBox(height: 14),
          Text(
            cancelled
                ? 'Connect your Gmail to triage recent messages.'
                : error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(cancelled ? 'Connect Gmail' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
