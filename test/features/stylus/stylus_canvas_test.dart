import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/stylus/widgets/stylus_canvas.dart';
import 'package:marine_survey_app/features/stylus/widgets/stylus_models.dart';

Widget _host(GlobalKey<StylusCanvasState> key, StylusBackground bg,
    {bool eraser = false}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 300,
        child: StylusCanvas(
          key: key,
          background: bg,
          color: const Color(0xFF111111),
          width: 6,
          isEraser: eraser,
        ),
      ),
    ),
  );
}

void main() {
  group('StylusBackground', () {
    test('blank constructor carries the paper style and no image', () {
      const bg = StylusBackground.blank(BlankPaper.grid);
      expect(bg.mode, StylusBackgroundMode.blank);
      expect(bg.paper, BlankPaper.grid);
      expect(bg.hasImage, isFalse);
    });

    test('photo background reports an image when bytes are present', () {
      final bg = StylusBackground(
        mode: StylusBackgroundMode.photo,
        imageBytes: Uint8List.fromList([1, 2, 3]),
        sourceLabel: 'engine',
      );
      expect(bg.hasImage, isTrue);
      expect(bg.sourceLabel, 'engine');
    });

    test('every background mode has a non-empty label', () {
      for (final mode in StylusBackgroundMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });
  });

  group('buildStrokePath', () {
    test('produces a non-empty path for a multi-point stroke', () {
      const stroke = DrawnStroke(
        points: [Offset(0, 0), Offset(10, 10), Offset(20, 5)],
        color: Color(0xFF000000),
        width: 6,
      );
      final path = buildStrokePath(stroke);
      expect(path.getBounds().isEmpty, isFalse);
    });
  });

  group('StylusCanvas', () {
    testWidgets('records, undoes and clears strokes', (tester) async {
      final key = GlobalKey<StylusCanvasState>();
      await tester.pumpWidget(_host(key, const StylusBackground.blank()));

      expect(key.currentState!.isEmpty, isTrue);

      // Draw one stroke.
      final gesture = await tester.startGesture(const Offset(60, 60));
      await gesture.moveTo(const Offset(120, 120));
      await gesture.moveTo(const Offset(180, 90));
      await gesture.up();
      await tester.pump();
      expect(key.currentState!.strokeCount, 1);

      // Draw a second stroke.
      final g2 = await tester.startGesture(const Offset(80, 200));
      await g2.moveTo(const Offset(200, 210));
      await g2.up();
      await tester.pump();
      expect(key.currentState!.strokeCount, 2);

      key.currentState!.undo();
      await tester.pump();
      expect(key.currentState!.strokeCount, 1);

      key.currentState!.clear();
      await tester.pump();
      expect(key.currentState!.isEmpty, isTrue);
    });

    testWidgets('exports the drawing as PNG bytes', (tester) async {
      final key = GlobalKey<StylusCanvasState>();
      await tester.pumpWidget(_host(key, const StylusBackground.blank()));

      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveTo(const Offset(150, 150));
      await gesture.up();
      await tester.pump();

      // toImage() drives a real engine operation, so it must run outside the
      // fake-async zone via runAsync.
      Uint8List? png;
      await tester.runAsync(() async {
        png = await key.currentState!.exportPng(pixelRatio: 1);
      });
      expect(png, isNotNull);
      expect(png!.length, greaterThan(8));
      // PNG magic number.
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets('renders each blank paper style without error',
        (tester) async {
      for (final paper in BlankPaper.values) {
        final key = GlobalKey<StylusCanvasState>();
        await tester.pumpWidget(_host(key, StylusBackground.blank(paper)));
        await tester.pump();
        expect(find.byType(StylusCanvas), findsOneWidget);
      }
    });
  });
}
