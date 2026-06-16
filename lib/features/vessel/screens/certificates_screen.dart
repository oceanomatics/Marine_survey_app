// lib/features/vessel/screens/certificates_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/certificates_provider.dart';
import '../widgets/certificate_card.dart';
import '../widgets/add_certificate_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificatesProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Certificates'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context, ref),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Certificate',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: certsAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading certificates...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (certs) => certs.isEmpty
            ? _EmptyState(onAdd: () => _showAddEdit(context, ref))
            : _CertBody(
                certs: certs,
                onEdit: (c) => _showAddEdit(context, ref, existing: c),
                onDelete: (id) => ref
                    .read(certificatesProvider(caseId).notifier)
                    .deleteCertificate(id),
              ),
      ),
    );
  }

  void _showAddEdit(BuildContext context, WidgetRef ref,
      {CertificateModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCertificateSheet(
        caseId: caseId,
        existing: existing,
        onSave: (cert) async {
          if (existing != null) {
            await ref
                .read(certificatesProvider(caseId).notifier)
                .updateCertificate(cert);
          } else {
            await ref
                .read(certificatesProvider(caseId).notifier)
                .addCertificate(cert);
          }
        },
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

class _CertBody extends StatelessWidget {
  const _CertBody({
    required this.certs,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CertificateModel> certs;
  final ValueChanged<CertificateModel> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    // Summary stats
    final valid    = certs.where((c) =>
        c.effectiveStatus == CertStatus.valid).length;
    final expiring = certs.where((c) => c.isExpiringSoon).length;
    final expired  = certs.where((c) =>
        c.effectiveStatus == CertStatus.expired).length;
    final aiExtracted = certs.where((c) => c.extractedAuto).length;

    return CustomScrollView(
      slivers: [
        // ── Status summary ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: _StatusSummary(
            total:      certs.length,
            valid:      valid,
            expiring:   expiring,
            expired:    expired,
            aiExtracted: aiExtracted,
          ),
        ),

        // ── Certificate list ───────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: EdgeInsets.fromLTRB(
                  12, i == 0 ? 8 : 0, 12, 8),
              child: CertificateCard(
                cert: certs[i],
                onEdit: () => onEdit(certs[i]),
                onDelete: () => _confirmDelete(
                    context, certs[i].certId),
              ),
            ),
            childCount: certs.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String certId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete certificate?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(certId);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Status summary banner ──────────────────────────────────────────────────

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.total,
    required this.valid,
    required this.expiring,
    required this.expired,
    required this.aiExtracted,
  });

  final int total, valid, expiring, expired, aiExtracted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(children: [
            _Stat(total.toString(),    'Total',     AppColors.navy),
            _Div(),
            _Stat(valid.toString(),    'Valid',     AppColors.success),
            _Div(),
            _Stat(expiring.toString(), 'Expiring',  AppColors.warning),
            _Div(),
            _Stat(expired.toString(),  'Expired',   AppColors.error),
          ]),
          if (aiExtracted > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 12, color: AppColors.purple),
                  const SizedBox(width: 5),
                  Text(
                    '$aiExtracted certificate${aiExtracted == 1 ? '' : 's'} '
                    'extracted by AI',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.purple,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.border);
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No certificates recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Certificates can be added manually here\n'
            'or automatically via the Document Vault\n'
            'when you import a certificate file.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add certificate'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}
