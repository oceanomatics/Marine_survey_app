// lib/features/capture/screens/camera_screen.dart
// Camera screen stub — full implementation in next session
// QuickCaptureSheet is now fully wired to Supabase

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quick_capture_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen(
      {super.key, required this.caseId, this.reportSection, this.stage});
  final String caseId;
  final String? reportSection;
  final String? stage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BackAppBar(title: const Text('Camera')),
      body: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.camera_alt_outlined,
              size: 64, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text('Camera — coming next session',
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ── Quick Capture Sheet ────────────────────────────────────────────────────
// Used from Case Home FAB — now saves to Supabase via provider

class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<QuickCaptureSheet> createState() =>
      _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Quick Capture',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Capture it now — sort it later',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'e.g. "Check run hours on port thruster"\n'
                  '"Ask chief about lube oil analysis date"\n'
                  '"Photo of crankcase door needed"',
            ),
          ),
          const SizedBox(height: 14),
          // Quick category hint tags (visual only — routing done in inbox)
          const Row(children: [
            _QuickTag('🔧 Damage', AppColors.coral),
            SizedBox(width: 8),
            _QuickTag('📋 Checklist', AppColors.green),
            SizedBox(width: 8),
            _QuickTag('📄 Document', AppColors.amber),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save to Inbox'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(quickCaptureProvider(widget.caseId).notifier)
          .addCapture(caseId: widget.caseId, content: text);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QuickTag extends StatelessWidget {
  const _QuickTag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}
