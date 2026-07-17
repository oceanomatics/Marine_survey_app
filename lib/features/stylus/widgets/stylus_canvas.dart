// lib/features/stylus/widgets/stylus_canvas.dart
//
// The drawing surface: a RepaintBoundary wrapping the backdrop + ink layer,
// captured to PNG on save. Drawing state (strokes, undo/clear) lives here and
// is driven imperatively from the parent screen via a GlobalKey.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'stylus_models.dart';

class StylusCanvas extends StatefulWidget {
  const StylusCanvas({
    super.key,
    required this.background,
    required this.color,
    required this.width,
    required this.isEraser,
    this.onChanged,
  });

  final StylusBackground background;
  final Color color;
  final double width;
  final bool isEraser;

  /// Fired whenever the number of strokes changes so the parent can enable /
  /// disable the undo / clear / save controls.
  final ValueChanged<int>? onChanged;

  @override
  StylusCanvasState createState() => StylusCanvasState();
}

class StylusCanvasState extends State<StylusCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<DrawnStroke> _strokes = [];
  DrawnStroke? _active;

  int get strokeCount => _strokes.length;
  bool get isEmpty => _strokes.isEmpty;

  void undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    widget.onChanged?.call(_strokes.length);
  }

  void clear() {
    if (_strokes.isEmpty && _active == null) return;
    setState(() {
      _strokes.clear();
      _active = null;
    });
    widget.onChanged?.call(0);
  }

  void _start(Offset p) {
    setState(() {
      _active = DrawnStroke(
        points: [p],
        color: widget.color,
        width: widget.isEraser ? widget.width * 2.2 : widget.width,
        isEraser: widget.isEraser,
      );
    });
  }

  void _extend(Offset p) {
    final active = _active;
    if (active == null) return;
    setState(() => _active = active.copyWith(points: [...active.points, p]));
  }

  void _end() {
    final active = _active;
    if (active == null) return;
    setState(() {
      if (active.points.isNotEmpty) _strokes.add(active);
      _active = null;
    });
    widget.onChanged?.call(_strokes.length);
  }

  /// Rasterises the composited canvas (backdrop + ink) to PNG bytes.
  Future<Uint8List?> exportPng({double pixelRatio = 3.0}) async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    return encodeImagePng(image);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _start(e.localPosition),
              onPointerMove: (e) => _extend(e.localPosition),
              onPointerUp: (_) => _end(),
              onPointerCancel: (_) => _end(),
              child: CustomPaint(
                painter: StrokesPainter(strokes: _strokes, active: _active),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final bg = widget.background;
    // A photo / document backdrop always sits on white so the exported PNG has
    // an opaque base and eraser reveals white rather than transparency.
    if (bg.hasImage) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Image.memory(bg.imageBytes!, fit: BoxFit.contain),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: CustomPaint(
        painter: BlankPaperPainter(paper: bg.paper),
        size: Size.infinite,
      ),
    );
  }
}
