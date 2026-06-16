// lib/features/vessel/widgets/certificate_card.dart

import 'package:flutter/material.dart';
import '../providers/certificates_provider.dart';
import '../../../shared/theme/app_theme.dart';

class CertificateCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final status  = cert.effectiveStatus;
    final expiring = cert.isExpiringSoon &&
        status != CertStatus.expired;

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

            // ── Footer ───────────────────────────────────────────────
            if (cert.certNumber != null || cert.extractedAuto) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (cert.certNumber != null)
                  Text('No. ${cert.certNumber}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary)),
                const Spacer(),
                if (cert.extractedAuto)
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
