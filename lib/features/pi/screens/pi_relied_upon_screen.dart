// lib/features/pi/screens/pi_relied_upon_screen.dart
//
// P&I / Expert — Facts & Documents Relied Upon (spec §4.3). An itemised list
// of the specific facts and documents the opinion relies on, each with an
// optional reference/date. Feeds the expert-report "relied upon" section.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../providers/pi_relied_upon_provider.dart';

const _kPiColor = Color(0xFF3B4A8C);

class PiReliedUponScreen extends ConsumerWidget {
  const PiReliedUponScreen({super.key, required this.caseId});
  final String caseId;

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add item relied upon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Fact or document relied upon'),
            ),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                  labelText: 'Reference / date (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (saved == true && descCtrl.text.trim().isNotEmpty) {
      await ref.read(piReliedUponProvider(caseId).notifier).add(
            descCtrl.text.trim(),
            reference:
                refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
          );
      if (context.mounted) showSavedToast(context, label: 'Item added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(piReliedUponProvider(caseId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Facts & Documents Relied Upon')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        backgroundColor: _kPiColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Nothing relied upon recorded yet',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: ListTile(
                  leading: Text('${i + 1}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  title: Text(r.description),
                  subtitle: (r.reference != null && r.reference!.isNotEmpty)
                      ? Text(r.reference!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => ref
                        .read(piReliedUponProvider(caseId).notifier)
                        .delete(r.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
