import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Perspective document flattener.
///
/// Given the four corners of a document visible in a photo, renders a
/// geometrically correct rectangle using a fine-grid GPU warp (dart:ui
/// drawVertices + ImageShader). No external image libraries required.
///
/// Corner order is always: top-left, top-right, bottom-right, bottom-left.
class DocumentWarp {
  DocumentWarp._();

  /// Perspective-correct a document image.
  ///
  /// [srcImage]   – the decoded source photo as a ui.Image.
  /// [srcCorners] – 4 corners in pixel space [TL, TR, BR, BL].
  /// [maxLongSide]– caps the longer output dimension (default 1400 px).
  /// [gridN]      – grid subdivisions; 24 gives sub-pixel accuracy with no
  ///                visible difference from a true per-pixel warp.
  ///
  /// Returns PNG bytes of the corrected, upright document.
  static Future<Uint8List> warp({
    required ui.Image srcImage,
    required List<Offset> srcCorners,
    int maxLongSide = 1400,
    int gridN = 24,
  }) async {
    assert(srcCorners.length == 4, 'Need exactly 4 corners: TL TR BR BL');

    // Determine output dimensions from the detected edge lengths.
    final topW    = (srcCorners[1] - srcCorners[0]).distance;
    final bottomW = (srcCorners[2] - srcCorners[3]).distance;
    final leftH   = (srcCorners[3] - srcCorners[0]).distance;
    final rightH  = (srcCorners[2] - srcCorners[1]).distance;
    final rawW = (topW + bottomW) / 2;
    final rawH = (leftH + rightH) / 2;

    // Scale so neither side exceeds maxLongSide.
    final scale = (rawW > rawH)
        ? (rawW > maxLongSide ? maxLongSide / rawW : 1.0)
        : (rawH > maxLongSide ? maxLongSide / rawH : 1.0);
    final outW = (rawW * scale).round().clamp(64, 4096);
    final outH = (rawH * scale).round().clamp(64, 4096);

    // Destination rectangle corners.
    final dst = [
      Offset.zero,
      Offset(outW.toDouble(), 0),
      Offset(outW.toDouble(), outH.toDouble()),
      Offset(0, outH.toDouble()),
    ];

    // H maps dst→src so each output pixel knows which source pixel to sample.
    final H = _computeHomography(dst, srcCorners);

    // Build a gridN×gridN mesh of triangles.
    final positions  = <Offset>[];
    final texCoords  = <Offset>[];
    final indices    = <int>[];

    for (int row = 0; row <= gridN; row++) {
      for (int col = 0; col <= gridN; col++) {
        final dstPt = Offset(
          col / gridN * outW,
          row / gridN * outH,
        );
        positions.add(dstPt);
        texCoords.add(_applyH(H, dstPt));
      }
    }

    final stride = gridN + 1;
    for (int row = 0; row < gridN; row++) {
      for (int col = 0; col < gridN; col++) {
        final i = row * stride + col;
        indices
          ..add(i)          ..add(i + 1)         ..add(i + stride)
          ..add(i + 1)      ..add(i + stride + 1) ..add(i + stride);
      }
    }

    final verts = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: indices,
    );

    // ImageShader maps pixel tex-coords to [0,1] for GPU sampling.
    final shaderMatrix = Matrix4.diagonal3Values(
      1.0 / srcImage.width.toDouble(),
      1.0 / srcImage.height.toDouble(),
      1.0,
    ).storage;

    final shader = ui.ImageShader(
      srcImage,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      shaderMatrix,
    );

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawVertices(
      verts,
      BlendMode.src,
      Paint()..shader = shader,
    );

    final picture = recorder.endRecording();
    final img     = await picture.toImage(outW, outH);
    final bd      = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();

    return bd!.buffer.asUint8List();
  }

  // ── Homography (DLT) ────────────────────────────────────────────────────

  /// Compute the 3×3 homography matrix (row-major, 9 elements) that maps
  /// each point in [src] to the corresponding point in [dst].
  static List<double> _computeHomography(
    List<Offset> src,
    List<Offset> dst,
  ) {
    final A = <List<double>>[];
    final b = <double>[];
    for (int i = 0; i < 4; i++) {
      final xs = src[i].dx, ys = src[i].dy;
      final xd = dst[i].dx, yd = dst[i].dy;
      A.add([-xs, -ys, -1, 0, 0, 0, xd * xs, xd * ys]);
      b.add(-xd);
      A.add([0, 0, 0, -xs, -ys, -1, yd * xs, yd * ys]);
      b.add(-yd);
    }
    final h = _solveLinear(A, b);
    return [...h, 1.0]; // h[8] = 1 (scale fixed)
  }

  /// Apply homography H to a point (homogeneous division).
  static Offset _applyH(List<double> H, Offset p) {
    final w = H[6] * p.dx + H[7] * p.dy + H[8];
    if (w.abs() < 1e-10) return Offset.zero;
    return Offset(
      (H[0] * p.dx + H[1] * p.dy + H[2]) / w,
      (H[3] * p.dx + H[4] * p.dy + H[5]) / w,
    );
  }

  // ── Gaussian elimination ─────────────────────────────────────────────────

  /// Solve Ax = b (8×8 system) with partial pivoting.
  static List<double> _solveLinear(
    List<List<double>> A,
    List<double> b,
  ) {
    final n = b.length;
    // Augmented matrix [A | b]
    final m = List.generate(n, (i) => [...A[i], b[i]]);

    for (int col = 0; col < n; col++) {
      // Partial pivot
      var pivotRow = col;
      for (int row = col + 1; row < n; row++) {
        if (m[row][col].abs() > m[pivotRow][col].abs()) pivotRow = row;
      }
      final tmp = m[col]; m[col] = m[pivotRow]; m[pivotRow] = tmp;

      final pivot = m[col][col];
      if (pivot.abs() < 1e-12) continue;

      for (int row = col + 1; row < n; row++) {
        final f = m[row][col] / pivot;
        for (int c = col; c <= n; c++) { m[row][c] -= f * m[col][c]; }
      }
    }

    final x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = m[i][n];
      for (int j = i + 1; j < n; j++) { x[i] -= m[i][j] * x[j]; }
      x[i] /= m[i][i];
    }
    return x;
  }
}
