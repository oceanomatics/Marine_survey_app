// lib/features/stylus/widgets/stylus_models.dart
//
// Value types + painters for the Stylus annotation tool. Kept free of any
// Riverpod / provider imports so they're trivially unit-testable.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

// ── Background ──────────────────────────────────────────────────────────────

/// Which kind of backdrop the surveyor draws on top of.
enum StylusBackgroundMode {
  blank('Blank'),
  photo('Case Photo'),
  document('Document Page');

  const StylusBackgroundMode(this.label);
  final String label;
}

/// Paper style for the blank-canvas background.
enum BlankPaper {
  plain('Plain', Icons.crop_portrait),
  ruled('Ruled', Icons.notes),
  grid('Grid', Icons.grid_4x4);

  const BlankPaper(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Full description of the current backdrop. When [mode] is
/// [StylusBackgroundMode.blank] only [paper] matters; otherwise [imageBytes]
/// carries the decoded photo / rendered document page to paint behind the ink.
@immutable
class StylusBackground {
  const StylusBackground({
    required this.mode,
    this.paper = BlankPaper.plain,
    this.imageBytes,
    this.sourceLabel,
  });

  final StylusBackgroundMode mode;
  final BlankPaper paper;
  final Uint8List? imageBytes;
  final String? sourceLabel;

  const StylusBackground.blank([this.paper = BlankPaper.plain])
      : mode = StylusBackgroundMode.blank,
        imageBytes = null,
        sourceLabel = null;

  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
}

// ── Stroke ──────────────────────────────────────────────────────────────────

/// A single freehand stroke captured on the canvas.
@immutable
class DrawnStroke {
  const DrawnStroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  DrawnStroke copyWith({List<Offset>? points}) => DrawnStroke(
        points: points ?? this.points,
        color: color,
        width: width,
        isEraser: isEraser,
      );
}

/// Builds the filled outline path for a stroke via perfect_freehand — the
/// same technique used by the report sign-off pad.
Path buildStrokePath(DrawnStroke stroke, {bool isComplete = true}) {
  final pts = stroke.points
      .map((o) => PointVector(o.dx, o.dy))
      .toList(growable: false);
  final outline = getStroke(
    pts,
    options: StrokeOptions(
      size: stroke.width,
      thinning: 0.4,
      smoothing: 0.5,
      streamline: 0.5,
      isComplete: isComplete,
    ),
  );
  final path = Path();
  if (outline.isEmpty) return path;
  path.moveTo(outline.first.dx, outline.first.dy);
  for (final pt in outline.skip(1)) {
    path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  return path;
}

// ── Painters ────────────────────────────────────────────────────────────────

/// Paints the blank-paper backdrop (plain / ruled lines / grid).
class BlankPaperPainter extends CustomPainter {
  const BlankPaperPainter({
    required this.paper,
    this.lineColor = const Color(0xFFCBD5E1),
    this.spacing = 28.0,
  });

  final BlankPaper paper;
  final Color lineColor;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (paper == BlankPaper.plain) return;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    if (paper == BlankPaper.grid) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(BlankPaperPainter old) =>
      old.paper != paper || old.lineColor != lineColor || old.spacing != spacing;
}

/// Paints the ink layer. Uses a transparent [saveLayer] so eraser strokes
/// ([BlendMode.clear]) remove only previously-drawn ink and reveal whatever
/// backdrop sits beneath the canvas, rather than smearing background colour.
class StrokesPainter extends CustomPainter {
  const StrokesPainter({required this.strokes, this.active});

  final List<DrawnStroke> strokes;
  final DrawnStroke? active;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...strokes, if (active != null) active!];
    if (all.isEmpty) return;
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in all) {
      final isLive = identical(stroke, active);
      final path = buildStrokePath(stroke, isComplete: !isLive);
      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill;
      if (stroke.isEraser) {
        paint
          ..color = const Color(0xFFFFFFFF)
          ..blendMode = BlendMode.clear;
      } else {
        paint.color = stroke.color;
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StrokesPainter old) =>
      old.strokes != strokes || old.active != active;
}

// ── Palette ─────────────────────────────────────────────────────────────────

/// Pen colours offered in the toolbar. High-contrast set that reads on both
/// white paper and photo/document backdrops.
const List<Color> kStylusPalette = [
  Color(0xFF111111), // near-black
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
  Color(0xFF8E24AA), // purple
  Color(0xFFFFFFFF), // white (for dark photos)
];

/// Pen tip sizes (logical px) offered in the toolbar.
const List<double> kStylusWidths = [3, 6, 10, 18];

/// Convenience: encode a [ui.Image] to PNG bytes.
Future<Uint8List?> encodeImagePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
