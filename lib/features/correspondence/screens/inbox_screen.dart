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

const _kColor = Color(0xFF2A6099);

/// Best short label for a case in the picker / snackbar: composite title if
/// set, else vessel name, else the technical file number.
String _caseLabel(CaseModel c) {
  if ((c.title ?? '').trim().isNotEmpty) return c.title!.trim();
  if ((c.vesselName ?? '').trim().isNotEmpty) return c.vesselName!.trim();
  return c.technicalFileNo;
}

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

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

  Future<void> _linkToCase(GmailMessageSummary msg) async {
    final selected = await showModalBottomSheet<CaseModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CasePickerSheet(),
    );
    if (selected == null || !mounted) return;

    setState(() => _busyId = msg.id);
    try {
      final bytes = await GmailService.fetchRawMessage(msg.id);
      await ref.read(correspondenceProvider(selected.caseId).notifier).importEml(
            caseId: selected.caseId,
            bytes: bytes,
            filename: '${msg.subject}.eml',
          );
      if (!mounted) return;
      setState(() => _handled.add(msg.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Filed to "${_caseLabel(selected)}" — Correspondence'),
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inboxMessagesProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Inbox', style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(inboxMessagesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const _TriageBanner(),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e,
                onRetry: () => ref.invalidate(inboxMessagesProvider),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No recent messages.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => _MessageCard(
                    msg: messages[i],
                    handled: _handled.contains(messages[i].id),
                    busy: _busyId == messages[i].id,
                    onLink: () => _linkToCase(messages[i]),
                    onNewCase: () => _startNewCase(messages[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TriageBanner extends StatelessWidget {
  const _TriageBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kColor.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: const Row(
        children: [
          Icon(Icons.rule_folder_outlined, size: 16, color: _kColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Triage: file each email to a case, or start a new one. '
              'This is not a full mailbox.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.msg,
    required this.handled,
    required this.busy,
    required this.onLink,
    required this.onNewCase,
  });

  final GmailMessageSummary msg;
  final bool handled;
  final bool busy;
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
                if (msg.date != null)
                  Text(_shortDate(msg.date!),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
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
    try {
      return DateFormat('dd MMM').format(DateTime.parse(rfc822Date));
    } catch (_) {
      return '';
    }
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
