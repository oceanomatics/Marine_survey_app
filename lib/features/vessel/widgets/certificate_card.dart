// lib/features/vessel/widgets/certificate_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/certificates_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../../core/api/supabase_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';

class CertificateCard extends ConsumerWidget {
  const CertificateCard({
    super.key,
    required this.cert,
    required this.onEdit,
    required this.onDelete,
  });

  final CertificateModel cert;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status  = cert.effectiveStatus;
    final expiring = cert.isExpiringSoon &&
        status != CertStatus.expired;

    // Resolve the source document (if any) from the Doc Vault.
    final docs = ref.watch(documentProvider(cert.caseId)).value ?? const [];
    DocumentModel? sourceDoc;
    if (cert.sourceDocId != null) {
      for (final d in docs) {
        if (d.docId == cert.sourceDocId) {
          sourceDoc = d;
          break;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(children: [
              // Icon
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_certIcon(cert.certType),
                    color: _statusFg(status), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.certName ?? cert.certType.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    if (cert.issuingAuthority != null)
                      Text(cert.issuingAuthority!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Status badge
              _StatusBadge(status: status, expiring: expiring),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.textTertiary),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 15),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          color: AppColors.error, size: 15),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(
                              color: AppColors.error, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 12),

            // ── Date grid ────────────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (cert.issueDate != null)
                  _DateField('Issued', cert.issueDate!, false),
                if (cert.expiryDate != null)
                  _DateField(
                    'Expires',
                    cert.expiryDate!,
                    cert.effectiveStatus == CertStatus.expired ||
                        expiring,
                  ),
                if (cert.annualSurveyDate != null)
                  _DateField(
                      'Annual survey', cert.annualSurveyDate!, false),
              ],
            ),

            // ── Expiry warning ────────────────────────────────────────
            if (expiring && cert.daysToExpiry != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time,
                      size: 13, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Expires in ${cert.daysToExpiry} days',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],

            if (cert.effectiveStatus == CertStatus.expired) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 13, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    'Expired ${cert.daysToExpiry!.abs()} days ago',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ],

            // ── Source document (Doc Vault link + thumbnail) ─────────
            if (sourceDoc != null) ...[
              const SizedBox(height: 10),
              _SourceDocRow(
                doc: sourceDoc,
                extractionSource: _extractionSource(cert, sourceDoc),
              ),
            ],

            // ── Footer ───────────────────────────────────────────────
            if (cert.certNumber != null ||
                (cert.extractedAuto && sourceDoc == null)) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (cert.certNumber != null)
                  Text('No. ${cert.certNumber}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary)),
                const Spacer(),
                // Fallback badge when the source doc is not (or no longer)
                // in the vault but the cert was AI-extracted.
                if (cert.extractedAuto && sourceDoc == null)
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome,
                        size: 11, color: AppColors.purple),
                    SizedBox(width: 3),
                    Text('AI extracted',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.purple,
                            fontWeight: FontWeight.w500)),
                  ]),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Human-readable extraction provenance for the certificate.
  String _extractionSource(CertificateModel cert, DocumentModel doc) {
    final from = switch (doc.docCategory) {
      DocCategory.certificate => 'the certificate',
      DocCategory.classSurveyReport => 'a class survey report',
      DocCategory.conditionOfClass => 'a condition-of-class report',
      DocCategory.inspectionReport => 'an inspection report',
      _ => doc.docCategory?.label ?? 'source document',
    };
    return cert.extractedAuto
        ? 'AI-extracted from $from'
        : 'Linked to $from';
  }

  Color _statusBg(CertStatus s) => switch (s) {
        CertStatus.valid     => AppColors.lightGreen,
        CertStatus.expired   => AppColors.lightCoral,
        CertStatus.suspended => AppColors.lightAmber,
        CertStatus.notSighted => AppColors.lightAmber,
        CertStatus.tbc       => AppColors.lightPurple,
      };

  Color _statusFg(CertStatus s) => switch (s) {
        CertStatus.valid     => AppColors.green,
        CertStatus.expired   => AppColors.error,
        CertStatus.suspended => AppColors.amber,
        CertStatus.notSighted => AppColors.amber,
        CertStatus.tbc       => AppColors.purple,
      };

  IconData _certIcon(CertType t) => switch (t) {
        CertType.classCertificate   => Icons.verified_outlined,
        CertType.doc                => Icons.business_center_outlined,
        CertType.smc                => Icons.security_outlined,
        CertType.loadLine           => Icons.water_outlined,
        CertType.marpol             => Icons.eco_outlined,
        CertType.pscInspection      => Icons.fact_check_outlined,
        CertType.dpCertificate      => Icons.gps_fixed_outlined,
        _                           => Icons.description_outlined,
      };
}

// ── Source document row (thumbnail + tap-to-view + provenance) ──────────────

class _SourceDocRow extends StatefulWidget {
  const _SourceDocRow({required this.doc, required this.extractionSource});
  final DocumentModel doc;
  final String extractionSource;

  @override
  State<_SourceDocRow> createState() => _SourceDocRowState();
}

class _SourceDocRowState extends State<_SourceDocRow> {
  Future<String?>? _urlFuture;
  bool _opening = false;

  bool get _hasFile => widget.doc.hasFile && widget.doc.filePath != null;

  @override
  void initState() {
    super.initState();
    if (_hasFile) {
      _urlFuture = _signedUrl();
    }
  }

  Future<String?> _signedUrl() async {
    try {
      return await SupabaseService.client.storage
          .from('documents')
          .createSignedUrl(widget.doc.filePath!, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _open() async {
    if (!_hasFile || _opening) return;
    setState(() => _opening = true);
    try {
      final url = await (_urlFuture ?? _signedUrl());
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open document')));
        }
        return;
      }
      if (!mounted) return;
      if (widget.doc.isImage) {
        await showDialog<void>(
          context: context,
          builder: (_) => _ImageDialog(url: url, title: widget.doc.title),
        );
      } else {
        final uri = Uri.parse(url);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open document')));
        }
      }
    } catch (e, st) {
      if (mounted) {
        showError(context, 'Cannot open document: $e',
            error: e, stack: st, tag: 'Certificate');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _hasFile ? _open : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.midBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.midBlue.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          _thumbnail(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(
                    widget.doc.hasFile
                        ? Icons.folder_open_outlined
                        : Icons.link,
                    size: 11,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(widget.extractionSource,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary)),
                  ),
                ]),
              ],
            ),
          ),
          if (_hasFile)
            _opening
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.open_in_new,
                    size: 15, color: AppColors.midBlue),
        ]),
      ),
    );
  }

  Widget _thumbnail() {
    const size = 44.0;
    if (!_hasFile) {
      return _iconBox(Icons.link, size);
    }
    if (widget.doc.isImage && _urlFuture != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FutureBuilder<String?>(
          future: _urlFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _iconBox(Icons.image_outlined, size);
            }
            final url = snap.data;
            if (url == null) return _iconBox(Icons.broken_image_outlined, size);
            return Image.network(
              url,
              width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _iconBox(Icons.broken_image_outlined, size),
            );
          },
        ),
      );
    }
    // PDF / docx / other
    return _iconBox(
      widget.doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
      size,
    );
  }

  Widget _iconBox(IconData icon, double size) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: AppColors.midBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 20, color: AppColors.midBlue),
      );
}

class _ImageDialog extends StatelessWidget {
  const _ImageDialog({required this.url, required this.title});
  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          Flexible(
            child: InteractiveViewer(
              child: Image.network(url,
                  errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Could not load image',
                            style: TextStyle(color: Colors.white)),
                      )),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.expiring});
  final CertStatus status;
  final bool expiring;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (expiring && status != CertStatus.expired) {
      color = AppColors.warning;
      label = 'Expiring';
    } else {
      color = switch (status) {
        CertStatus.valid      => AppColors.success,
        CertStatus.expired    => AppColors.error,
        CertStatus.suspended  => AppColors.warning,
        CertStatus.notSighted => AppColors.amber,
        CertStatus.tbc        => AppColors.textSecondary,
      };
      label = status.label;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(this.label, this.date, this.highlight);
  final String label;
  final DateTime date;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          _fmt(date),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.error : AppColors.textPrimary),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
