// lib/features/settings/screens/debug_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/debug_logger.dart';
import '../../../shared/theme/app_theme.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  List<LogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DebugLogger.load();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear debug log?'),
        content: const Text('All log entries will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DebugLogger.clear();
      if (mounted) setState(() => _entries = []);
    }
  }

  void _copyAll() {
    final text = _entries.map((e) {
      final ts  = e.timestamp.toIso8601String();
      final hdr = '[$ts][${e.tag}] ${e.message}';
      return e.detail != null ? '$hdr\n${e.detail}' : hdr;
    }).join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copied to clipboard'),
          duration: Duration(seconds: 2)),
    );
  }

  void _showDetail(LogEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(children: [
                  _TagChip(e.tag),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fmtDate(e.timestamp),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    onPressed: () {
                      final txt = e.detail != null
                          ? '${e.message}\n\n${e.detail}'
                          : e.message;
                      Clipboard.setData(ClipboardData(text: txt));
                    },
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(e.message,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              if (e.detail != null) ...[
                const Divider(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SelectableText(
                      e.detail!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Debug Log'),
        actions: [
          if (_entries.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_all, color: Colors.white),
              tooltip: 'Copy all',
              onPressed: _copyAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Clear log',
              onPressed: _clear,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48, color: AppColors.success),
                      SizedBox(height: 12),
                      Text('No log entries',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      return _LogTile(
                        entry: e,
                        onTap: e.detail != null ? () => _showDetail(e) : null,
                      );
                    },
                  ),
                ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, this.onTap});
  final LogEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _TagChip(entry.tag),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fmtDate(entry.timestamp),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ),
                if (entry.detail != null)
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textTertiary),
              ]),
              const SizedBox(height: 5),
              Text(
                entry.message,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary, height: 1.3),
              ),
              if (entry.detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  entry.detail!.split('\n').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.error,
                      fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.tag);
  final String tag;

  static Color _color(String tag) => switch (tag.toLowerCase()) {
        'vessel'    => AppColors.midBlue,
        'import'    => AppColors.teal,
        'auth'      => AppColors.purple,
        'document'  => AppColors.amber,
        _           => AppColors.coral,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tag,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: c,
              letterSpacing: 0.4)),
    );
  }
}

String _fmtDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}:'
      '${d.second.toString().padLeft(2, '0')}';
}
