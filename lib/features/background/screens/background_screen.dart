// lib/features/background/screens/background_screen.dart
//
// The bespoke private context-cues panel previously duplicated here (and
// drifting from the shared widget every time the cue system changed — see
// docs/context_cue_system_review.md §2.2/§3.6) has been replaced with the
// shared `ContextCuesPanel`, same as Causation/Repairs/Additional
// Information — one implementation of the cue register, not five.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../providers/background_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/save_bar.dart';
import '../../../shared/widgets/context_cues_panel.dart';

const _kAccent = Color(0xFF2A6B9E);

class BackgroundScreen extends ConsumerStatefulWidget {
  const BackgroundScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<BackgroundScreen> createState() => _BackgroundScreenState();
}

class _BackgroundScreenState extends ConsumerState<BackgroundScreen> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _autosave);
  }

  Future<void> _autosave() async {
    if (!mounted) return;
    await _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(backgroundProvider(widget.caseId).notifier)
          .save(_ctrl.text);
      if (mounted) setState(() => _dirty = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundAsync = ref.watch(backgroundProvider(widget.caseId));

    return backgroundAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (bg) {
        if (_ctrl.text.isEmpty && bg.content.isNotEmpty) {
          _ctrl.text = bg.content;
          _ctrl.selection =
              TextSelection.collapsed(offset: _ctrl.text.length);
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: _BackgroundAppBar(
            dirty: _dirty,
            saving: _saving,
          ),
          bottomNavigationBar: SaveBar(
            visible: _dirty,
            saving: _saving,
            onSave: _doSave,
          ),
          body: Column(
            children: [
              // ── Narrative text editor ─────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: _onTextChanged,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Enter the background narrative for this case…\n\n'
                          'Describe the vessel\'s history, circumstances '
                          'leading to the incident, instruction details, '
                          'and any relevant pre-existing conditions.',
                      hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                          height: 1.6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: _kAccent, width: 1.5)),
                      contentPadding: const EdgeInsets.all(14),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                ),
              ),

              // ── Context cues panel (background-tagged notes) ───────
              ContextCuesPanel(
                caseId: widget.caseId,
                section: CaseSection.background,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────

class _BackgroundAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BackgroundAppBar({
    required this.dirty,
    required this.saving,
  });

  final bool dirty;
  final bool saving;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navy,
      title: Row(
        children: [
          const Text('Background',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          if (saving)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white54),
            )
          else if (!dirty)
            const Icon(Icons.cloud_done_outlined,
                color: Colors.white38, size: 15),
        ],
      ),
    );
  }
}
