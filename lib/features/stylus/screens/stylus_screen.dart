// lib/features/stylus/screens/stylus_screen.dart
//
// Full-screen stylus / finger annotation tool. Three backdrop modes (blank
// paper, a case photo, or a Doc Vault page), pen colours + widths, an eraser,
// undo and clear. Saving rasterises the composited canvas to PNG and pushes it
// through the standard photo pipeline (photoProvider.addPhoto) so the result
// becomes a case photo, uploaded to Drive like any other.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../photos/providers/photo_provider.dart';
import '../widgets/background_picker_sheet.dart';
import '../widgets/stylus_canvas.dart';
import '../widgets/stylus_models.dart';

class StylusScreen extends ConsumerStatefulWidget {
  const StylusScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<StylusScreen> createState() => _StylusScreenState();
}

class _StylusScreenState extends ConsumerState<StylusScreen> {
  final GlobalKey<StylusCanvasState> _canvasKey = GlobalKey();

  StylusBackground _background = const StylusBackground.blank();
  Color _color = kStylusPalette.first;
  double _width = kStylusWidths[1];
  bool _eraser = false;
  int _strokeCount = 0;
  bool _saving = false;

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/cases/${widget.caseId}');
    }
  }

  Future<void> _pickBackground() async {
    final chosen = await showBackgroundPicker(context, widget.caseId);
    if (chosen == null || !mounted) return;
    if (!_canvasKey.currentState!.isEmpty) {
      final replace = await _confirmReplace();
      if (replace != true) return;
    }
    setState(() => _background = chosen);
    _canvasKey.currentState?.clear();
  }

  Future<bool?> _confirmReplace() => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change background?'),
          content: const Text(
              'Changing the background will clear your current drawing.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Change & clear')),
          ],
        ),
      );

  Future<void> _save() async {
    final canvas = _canvasKey.currentState;
    if (canvas == null || canvas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save — draw something first')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await canvas.exportPng();
      if (bytes == null || bytes.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not capture the drawing')));
        return;
      }
      final caption = _captionFor(_background);
      await ref.read(photosProvider(widget.caseId).notifier).addPhoto(
            caseId: widget.caseId,
            bytes: bytes,
            caption: caption,
          );
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Annotation saved to case photos')));
      _leave();
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _captionFor(StylusBackground bg) {
    final base = switch (bg.mode) {
      StylusBackgroundMode.blank => 'Sketch',
      StylusBackgroundMode.photo => 'Annotated photo',
      StylusBackgroundMode.document => 'Annotated document',
    };
    final suffix = bg.sourceLabel != null && bg.sourceLabel!.isNotEmpty
        ? ' — ${bg.sourceLabel}'
        : '';
    return '$base$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A18),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leave,
        ),
        title: const Text('Stylus', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white, size: 20),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: StylusCanvas(
                  key: _canvasKey,
                  background: _background,
                  color: _color,
                  width: _width,
                  isEraser: _eraser,
                  onChanged: (n) => setState(() => _strokeCount = n),
                ),
              ),
            ),
          ),
          _toolbar(),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      color: const Color(0xFF25251F),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colour swatches
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in kStylusPalette)
                    _ColorDot(
                      color: c,
                      selected: !_eraser && c == _color,
                      onTap: () => setState(() {
                        _color = c;
                        _eraser = false;
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tools row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToolIcon(
                  icon: Icons.edit,
                  label: 'Pen',
                  active: !_eraser,
                  onTap: () => setState(() => _eraser = false),
                ),
                _ToolIcon(
                  icon: Icons.auto_fix_normal,
                  label: 'Eraser',
                  active: _eraser,
                  onTap: () => setState(() => _eraser = true),
                ),
                _WidthPicker(
                  widths: kStylusWidths,
                  selected: _width,
                  color: _eraser ? Colors.white : _color,
                  onSelected: (w) => setState(() => _width = w),
                ),
                _ToolIcon(
                  icon: Icons.undo,
                  label: 'Undo',
                  enabled: _strokeCount > 0,
                  onTap: () => _canvasKey.currentState?.undo(),
                ),
                _ToolIcon(
                  icon: Icons.delete_outline,
                  label: 'Clear',
                  enabled: _strokeCount > 0,
                  onTap: () => _canvasKey.currentState?.clear(),
                ),
                _ToolIcon(
                  icon: Icons.wallpaper,
                  label: 'Background',
                  onTap: _pickBackground,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar pieces ───────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  const _ColorDot(
      {required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Colors.white24
        : active
            ? AppColors.skyBlue
            : Colors.white;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _WidthPicker extends StatelessWidget {
  const _WidthPicker({
    required this.widths,
    required this.selected,
    required this.color,
    required this.onSelected,
  });
  final List<double> widths;
  final double selected;
  final Color color;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Pen size',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final w in widths)
          PopupMenuItem(
            value: w,
            child: Row(
              children: [
                Container(
                  width: w + 6,
                  height: w + 6,
                  decoration:
                      const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text('${w.toInt()} px'),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: Center(
                child: Container(
                  width: (selected).clamp(4, 18).toDouble(),
                  height: (selected).clamp(4, 18).toDouble(),
                  decoration: BoxDecoration(
                      color: color == Colors.white ? Colors.white : color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24)),
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text('Size', style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
