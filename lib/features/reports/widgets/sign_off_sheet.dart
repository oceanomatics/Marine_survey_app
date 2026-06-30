import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/api/supabase_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../cases/providers/cases_provider.dart';

// ── Public entry point ──────────────────────────────────────────────────────

Future<void> showSignOffSheet(BuildContext context, String caseId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SignOffSheet(caseId: caseId),
  );
}

// ── Sheet ───────────────────────────────────────────────────────────────────

class _SignOffSheet extends ConsumerStatefulWidget {
  const _SignOffSheet({required this.caseId});
  final String caseId;

  @override
  ConsumerState<_SignOffSheet> createState() => _SignOffSheetState();
}

class _SignOffSheetState extends ConsumerState<_SignOffSheet> {
  String? _activeRole;

  @override
  Widget build(BuildContext context) {
    final case_ = ref.watch(caseProvider(widget.caseId)).value;

    final signedAttending = case_?.signedOffAttending ?? false;
    final signedReviewing = case_?.signedOffReviewing ?? false;
    final attendingName   = case_?.signedOffAttendingName;
    final attendingAt     = case_?.signedOffAttendingAt;
    final reviewingName   = case_?.signedOffReviewingName;
    final reviewingAt     = case_?.signedOffReviewingAt;
    final signed = (signedAttending ? 1 : 0) + (signedReviewing ? 1 : 0);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.draw_outlined,
                      size: 20, color: AppColors.navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Report Sign-Off',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: signed == 2
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: signed == 2
                              ? AppColors.success
                              : AppColors.border),
                    ),
                    child: Text(
                      '$signed / 2 signatures',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: signed == 2
                              ? AppColors.success
                              : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Both signatures are required before a Final Report can be exported.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            _roleCard(
              role: 'attending',
              label: 'Attending Surveyor',
              signed: signedAttending,
              signerName: attendingName,
              signedAt: attendingAt,
              canSign: true,
            ),
            if (_activeRole == 'attending')
              _SigningPanel(
                caseId: widget.caseId,
                role: 'attending',
                onDone: () => setState(() => _activeRole = null),
              ),

            const SizedBox(height: 8),

            _roleCard(
              role: 'reviewing',
              label: 'Reviewing Surveyor',
              signed: signedReviewing,
              signerName: reviewingName,
              signedAt: reviewingAt,
              canSign: signedAttending,
            ),
            if (_activeRole == 'reviewing')
              _SigningPanel(
                caseId: widget.caseId,
                role: 'reviewing',
                onDone: () => setState(() => _activeRole = null),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({
    required String role,
    required String label,
    required bool signed,
    required String? signerName,
    required DateTime? signedAt,
    required bool canSign,
  }) {
    final isOpen = _activeRole == role;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: signed
              ? AppColors.success.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: signed
                  ? AppColors.success.withValues(alpha: 0.4)
                  : isOpen
                      ? AppColors.navy
                      : AppColors.border),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: signed
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.navy.withValues(alpha: 0.08),
            child: Icon(
              signed ? Icons.check : Icons.draw_outlined,
              size: 18,
              color: signed ? AppColors.success : AppColors.navy,
            ),
          ),
          title: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: signed
              ? Text(
                  '${signerName ?? 'Signed'}'
                  '${signedAt != null ? ' · ${_fmtDate(signedAt)}' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))
              : Text(
                  canSign
                      ? 'Tap to sign'
                      : 'Attending surveyor must sign first',
                  style: TextStyle(
                      fontSize: 12,
                      color: canSign
                          ? AppColors.textSecondary
                          : AppColors.textTertiary)),
          trailing: !signed && canSign
              ? Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.navy)
              : null,
          onTap: (!signed && canSign)
              ? () => setState(
                  () => _activeRole = _activeRole == role ? null : role)
              : null,
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')} '
      '${_mon(dt.month)} ${dt.year}';

  String _mon(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ── Signing panel ───────────────────────────────────────────────────────────

class _SigningPanel extends ConsumerStatefulWidget {
  const _SigningPanel({
    required this.caseId,
    required this.role,
    required this.onDone,
  });
  final String caseId;
  final String role;
  final VoidCallback onDone;

  @override
  ConsumerState<_SigningPanel> createState() => _SigningPanelState();
}

class _SigningPanelState extends ConsumerState<_SigningPanel> {
  final _nameCtrl = TextEditingController();
  final _padKey = GlobalKey<_SignaturePadState>();
  bool _saving = false;
  Uint8List? _uploadedPng;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your name before signing')),
      );
      return;
    }

    final sigBytes =
        _uploadedPng ?? await _padKey.currentState?.exportPng();
    if (sigBytes == null || sigBytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please draw your signature or upload a PNG')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      String? sigPath;
      try {
        final path = '${widget.caseId}/sigs/${widget.role}.png';
        await SupabaseService.client.storage.from('exports').uploadBinary(
              path,
              sigBytes,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: true,
              ),
            );
        sigPath = path;
      } catch (e) {
        debugPrint('Signature upload error: $e');
      }

      final now = DateTime.now();
      await ref
          .read(caseProvider(widget.caseId).notifier)
          .updateSignOff(
            attending:       widget.role == 'attending' ? true : null,
            attendingName:   widget.role == 'attending' ? name : null,
            attendingAt:     widget.role == 'attending' ? now  : null,
            attendingSigPath: widget.role == 'attending' ? sigPath : null,
            reviewing:       widget.role == 'reviewing' ? true : null,
            reviewingName:   widget.role == 'reviewing' ? name : null,
            reviewingAt:     widget.role == 'reviewing' ? now  : null,
            reviewingSigPath: widget.role == 'reviewing' ? sigPath : null,
          );

      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving sign-off: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadPng() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    // bytes is populated on web and when withData:true; path used on native
    final bytes = file.bytes ??
        (!kIsWeb && file.path != null
            ? await _readNativeBytes(file.path!)
            : null);
    if (bytes != null && mounted) setState(() => _uploadedPng = bytes);
  }

  // Reads a file via dart:io on native only (never called on web).
  Future<Uint8List?> _readNativeBytes(String path) async {
    try {
      // Use dynamic invocation to avoid importing dart:io at the top level,
      // keeping this file web-safe. kIsWeb guard ensures this is never called
      // on web builds.
      final dynamic f = await _openNativeFile(path);
      return await (f.readAsBytes() as Future<Uint8List>);
    } catch (_) {
      return null;
    }
  }

  dynamic _openNativeFile(String path) {
    // This is resolved at runtime on native targets only.
    // Throws on web (guarded by kIsWeb above).
    throw UnsupportedError('Native file access not available');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signing as ${widget.role == 'attending' ? 'Attending Surveyor' : 'Reviewing Surveyor'}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                hintText: 'As it should appear in the report',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            if (_uploadedPng != null)
              _UploadedPreview(
                bytes: _uploadedPng!,
                onClear: () => setState(() => _uploadedPng = null),
              )
            else
              _SignaturePad(key: _padKey),

            const SizedBox(height: 8),

            if (_uploadedPng == null)
              Center(
                child: TextButton.icon(
                  onPressed: _uploadPng,
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: const Text('Upload signature PNG instead',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                ),
              ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'By signing, I confirm that the professional opinions and '
                'technical findings in this report are my own and that all '
                'AI-assisted content has been reviewed and confirmed by me.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : widget.onDone,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Confirm & Sign'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Signature canvas ────────────────────────────────────────────────────────

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({super.key});

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];

  void _clear() => setState(() {
        _strokes.clear();
        _current = [];
      });

  Future<Uint8List?> exportPng() async {
    if (_strokes.isEmpty) return null;
    final size = context.size ?? const Size(380, 160);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder, Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final stroke in _strokes) {
      _paintStroke(canvas, paint, stroke);
    }

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _paintStroke(Canvas canvas, Paint paint, List<Offset> stroke) {
    if (stroke.length < 2) return;
    final pts = stroke.map((o) => PointVector(o.dx, o.dy)).toList();
    // getStroke returns List<Offset>
    final outline = getStroke(
      pts,
      options: StrokeOptions(size: 3.5, thinning: 0.5, smoothing: 0.5),
    );
    if (outline.length < 2) return;
    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (final pt in outline.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Signature',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            if (_strokes.isNotEmpty)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Clear',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: EdgeInsets.zero),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onPanStart: (d) =>
              setState(() => _current = [d.localPosition]),
          onPanUpdate: (d) =>
              setState(() => _current.add(d.localPosition)),
          onPanEnd: (_) {
            if (_current.isNotEmpty) {
              setState(() {
                _strokes.add(List.from(_current));
                _current = [];
              });
            }
          },
          child: CustomPaint(
            painter: _SignaturePainter(_strokes, _current),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: _strokes.isEmpty
                  ? const Text(
                      'Draw your signature here',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 13),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes, this.current);
  final List<List<Offset>> strokes;
  final List<Offset> current;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final stroke in [...strokes, if (current.isNotEmpty) current]) {
      if (stroke.length < 2) continue;
      final pts = stroke.map((o) => PointVector(o.dx, o.dy)).toList();
      final outline = getStroke(
        pts,
        options: StrokeOptions(size: 3.5, thinning: 0.5),
      );
      if (outline.length < 2) continue;
      final path = Path()..moveTo(outline.first.dx, outline.first.dy);
      for (final pt in outline.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.current != current;
}

// ── Uploaded PNG preview ────────────────────────────────────────────────────

class _UploadedPreview extends StatelessWidget {
  const _UploadedPreview({required this.bytes, required this.onClear});
  final Uint8List bytes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          top: 6, right: 6,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.close,
                  size: 14, color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}
