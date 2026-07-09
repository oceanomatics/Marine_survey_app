// lib/features/correspondence/screens/gmail_message_picker_screen.dart
//
// Gmail conversation (thread) browser for correspondence import.
//   1. Screen opens pre-filtered by case-derived keywords (vessel name, job
//      number, claim reference) so the surveyor sees case-relevant threads
//      first, not the whole inbox — editable via the search field.
//   2. Tapping a thread opens a conversation view listing every message in
//      it, in order, like a mail client — not an isolated single email.
//   3. Selected messages are downloaded as raw RFC822 bytes and returned to
//      the caller, which feeds each into the existing importEml() pipeline
//      (same pending-review/AI-extraction path as a manually uploaded .eml).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/gmail_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';

const _kColor = Color(0xFF2A6099);

class GmailMessagePickerScreen extends StatefulWidget {
  const GmailMessagePickerScreen({super.key, this.initialQuery});

  /// Pre-filled Gmail search query — typically built from case data
  /// (vessel name / job number / claim reference) by the caller.
  final String? initialQuery;

  @override
  State<GmailMessagePickerScreen> createState() =>
      _GmailMessagePickerScreenState();
}

class _GmailMessagePickerScreenState extends State<GmailMessagePickerScreen> {
  List<GmailThreadSummary> _threads = [];
  bool _loading = true;
  String? _error;
  late final TextEditingController _searchCtrl;

  // Ticked conversations (thread ids) for bulk import — separate from the
  // per-message selection inside a single thread's detail view.
  final Set<String> _selectedThreadIds = {};
  bool _importing = false;
  int _importDone = 0;
  int _importTotal = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    _load(query: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedThreadIds.clear();
    });
    try {
      final threads = await GmailService.listThreads(query: query);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } on GoogleSignInCancelled {
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleThread(String threadId) {
    setState(() {
      if (_selectedThreadIds.contains(threadId)) {
        _selectedThreadIds.remove(threadId);
      } else {
        _selectedThreadIds.add(threadId);
      }
    });
  }

  /// Opens the full conversation view for reviewing/partially selecting the
  /// messages within a single thread (independent of the tick-to-select bulk
  /// path below).
  Future<void> _openThread(GmailThreadSummary thread) async {
    final result = await Navigator.push<List<(Uint8List, String)>>(
      context,
      MaterialPageRoute(builder: (_) => _ThreadDetailScreen(thread: thread)),
    );
    if (result != null && result.isNotEmpty && mounted) {
      Navigator.pop(context, result);
    }
  }

  /// Imports every message from every ticked conversation in one go — the
  /// bulk path for "select a number of email trails" rather than reviewing
  /// each thread individually.
  Future<void> _importSelectedThreads() async {
    final toImport =
        _threads.where((t) => _selectedThreadIds.contains(t.id)).toList();
    if (toImport.isEmpty) return;

    final totalMessages =
        toImport.fold<int>(0, (sum, t) => sum + t.messageCount);
    setState(() {
      _importing = true;
      _importDone = 0;
      _importTotal = totalMessages;
    });

    final results = <(Uint8List, String)>[];
    try {
      for (final thread in toImport) {
        for (final msg in thread.messages) {
          final bytes = await GmailService.fetchRawMessage(msg.id);
          results.add((bytes, thread.subject));
          if (mounted) setState(() => _importDone++);
        }
      }
      if (mounted) Navigator.pop(context, results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Download failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Import from Gmail', style: TextStyle(fontSize: 15)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search (e.g. vessel name, job number)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onSubmitted: (v) =>
                      _load(query: v.trim().isEmpty ? null : v.trim()),
                  textInputAction: TextInputAction.search,
                ),
                if (widget.initialQuery != null &&
                    widget.initialQuery!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Pre-filtered to this case — edit the search to widen it',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget? _buildBottom() {
    if (_importing) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _importTotal > 0 ? _importDone / _importTotal : null,
                  backgroundColor: AppColors.border,
                  color: _kColor,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text('Downloading $_importDone / $_importTotal messages…',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_selectedThreadIds.isEmpty) return null;
    final n = _selectedThreadIds.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ElevatedButton.icon(
          onPressed: _importSelectedThreads,
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text('Import $n Conversation${n == 1 ? '' : 's'}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 52, color: AppColors.coral),
          const SizedBox(height: 14),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => _load(), child: const Text('Retry')),
        ]),
      );
    }
    if (_threads.isEmpty) {
      return const Center(
        child: Text('No matching conversations found.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _threads.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 58, endIndent: 16),
      itemBuilder: (_, i) {
        final t = _threads[i];
        final selected = _selectedThreadIds.contains(t.id);
        return ListTile(
          leading: Checkbox(
            value: selected,
            activeColor: _kColor,
            onChanged: (_) => _toggleThread(t.id),
          ),
          title: Text(t.subject,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [t.latest.from, t.latest.snippet]
                .where((s) => s.isNotEmpty)
                .join(' — '),
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (t.latest.date != null)
                    Text(_shortDate(t.latest.date!),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textTertiary)),
                  if (t.messageCount > 1) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${t.messageCount}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: _kColor,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'View conversation',
                onPressed: () => _openThread(t),
              ),
            ],
          ),
          onTap: () => _toggleThread(t.id),
        );
      },
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

// ── Conversation (thread) detail — full back-and-forth, select + import ────

class _ThreadDetailScreen extends StatefulWidget {
  const _ThreadDetailScreen({required this.thread});
  final GmailThreadSummary thread;

  @override
  State<_ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<_ThreadDetailScreen> {
  final Set<String> _selected = {};
  bool _downloading = false;
  int _downloadDone = 0;

  @override
  void initState() {
    super.initState();
    // Default: select every message in the conversation, since importing
    // the whole thread is the common case.
    _selected.addAll(widget.thread.messages.map((m) => m.id));
  }

  Future<void> _import() async {
    if (_selected.isEmpty) return;
    setState(() {
      _downloading = true;
      _downloadDone = 0;
    });

    final results = <(Uint8List, String)>[];
    try {
      for (final msg in widget.thread.messages) {
        if (!_selected.contains(msg.id)) continue;
        final bytes = await GmailService.fetchRawMessage(msg.id);
        results.add((bytes, widget.thread.subject));
        if (mounted) setState(() => _downloadDone++);
      }
      if (mounted) Navigator.pop(context, results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Download failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Text(thread.subject,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: thread.messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = thread.messages[i];
          final selected = _selected.contains(m.id);
          return Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: CheckboxListTile(
              value: selected,
              onChanged: _downloading
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selected.add(m.id);
                        } else {
                          _selected.remove(m.id);
                        }
                      }),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _kColor,
              title: Text(m.from,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.date != null)
                    Text(m.date!,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textTertiary)),
                  const SizedBox(height: 3),
                  Text(m.snippet,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _downloading || _selected.isEmpty ? null : _import,
            icon: _downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(
              _downloading
                  ? 'Downloading $_downloadDone / ${_selected.length}…'
                  : 'Import ${_selected.length} Message${_selected.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}
