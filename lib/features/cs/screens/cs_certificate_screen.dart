// lib/features/cs/screens/cs_certificate_screen.dart
//
// C&S §3.0 Certification & Documentation register — flag/statutory/class/
// safety-equipment certificates sighted during the survey, with issue/expiry
// dates. Expiry drives a simple validity badge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/cs_models.dart';
import '../providers/cs_certificate_provider.dart';

const _kCsColor = Color(0xFF1E6B5A);
final _dateFmt = DateFormat('dd MMM yyyy');

class CsCertificateScreen extends ConsumerWidget {
  const CsCertificateScreen({super.key, required this.caseId});
  final String caseId;

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final typeCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    DateTime? issued;
    DateTime? expiry;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> pick(bool isIssued) async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: DateTime(2026, 1, 1),
              firstDate: DateTime(2000),
              lastDate: DateTime(2040),
            );
            if (d != null) {
              setState(() => isIssued ? issued = d : expiry = d);
            }
          }

          return AlertDialog(
            title: const Text('Add certificate'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: typeCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Certificate type')),
                  TextField(
                      controller: placeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Issued at (optional)')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pick(true),
                          child: Text(issued == null
                              ? 'Issued date'
                              : _dateFmt.format(issued!)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pick(false),
                          child: Text(expiry == null
                              ? 'Expiry date'
                              : _dateFmt.format(expiry!)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Add')),
            ],
          );
        },
      ),
    );
    if (saved == true && typeCtrl.text.trim().isNotEmpty) {
      await ref.read(csCertificateProvider(caseId).notifier).add(
            certType: typeCtrl.text.trim(),
            issuedDate: issued,
            expiryDate: expiry,
            issuedPlace:
                placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim(),
          );
      if (context.mounted) showSavedToast(context, label: 'Certificate added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(csCertificateProvider(caseId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Certificate Register')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        backgroundColor: _kCsColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (certs) {
          if (certs.isEmpty) {
            return const Center(
              child: Text('No certificates recorded',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: certs.length,
            itemBuilder: (context, i) =>
                _CertTile(caseId: caseId, cert: certs[i]),
          );
        },
      ),
    );
  }
}

class _CertTile extends ConsumerWidget {
  const _CertTile({required this.caseId, required this.cert});
  final String caseId;
  final CsCertificateModel cert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired =
        cert.expiryDate != null && cert.expiryDate!.isBefore(DateTime(2026, 7, 23));
    final sub = [
      if (cert.issuedDate != null) 'Issued ${_dateFmt.format(cert.issuedDate!)}',
      if (cert.expiryDate != null) 'Expires ${_dateFmt.format(cert.expiryDate!)}',
      if (cert.issuedPlace != null && cert.issuedPlace!.isNotEmpty)
        cert.issuedPlace!,
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        title: Text(cert.certType,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cert.expiryDate != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (expired ? AppColors.coral : AppColors.green)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(expired ? 'Expired' : 'Valid',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: expired ? AppColors.coral : AppColors.green)),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.textSecondary,
              onPressed: () =>
                  ref.read(csCertificateProvider(caseId).notifier).delete(cert.id),
            ),
          ],
        ),
      ),
    );
  }
}
