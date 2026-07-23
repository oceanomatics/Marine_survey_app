// lib/features/dp/screens/dp_test_screen.dart
//
// DP FMEA Annual Trials — the test register. Each witnessed test carries a
// result and a finding category; WCF-tested and carried-forward flags support
// the IMCA compliance story. Backed by the trials_tests scaffold.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/dp_models.dart';
import '../providers/dp_test_provider.dart';

const _kDpColor = Color(0xFF0E7C86);

class DpTestScreen extends ConsumerWidget {
  const DpTestScreen({super.key, required this.caseId});
  final String caseId;

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final noCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final sysCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Test no.'),
            ),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Test name'),
            ),
            TextField(
              controller: sysCtrl,
              decoration: const InputDecoration(
                  labelText: 'System (thrusters, PMS, …)'),
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
    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(dpTestProvider(caseId).notifier).add(
            nameCtrl.text.trim(),
            testNo: int.tryParse(noCtrl.text.trim()),
            system: sysCtrl.text.trim().isEmpty ? null : sysCtrl.text.trim(),
          );
      if (context.mounted) showSavedToast(context, label: 'Test added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dpTestProvider(caseId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('DP Trials — Tests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        backgroundColor: _kDpColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tests) {
          if (tests.isEmpty) {
            return const Center(
              child: Text('No tests recorded yet',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: tests.length,
            itemBuilder: (context, i) =>
                _TestCard(caseId: caseId, test: tests[i]),
          );
        },
      ),
    );
  }
}

class _TestCard extends ConsumerWidget {
  const _TestCard({required this.caseId, required this.test});
  final String caseId;
  final DpTestModel test;

  Color _resultColor(DpTestResult r) {
    switch (r) {
      case DpTestResult.pass:
        return AppColors.green;
      case DpTestResult.fail:
        return AppColors.coral;
      case DpTestResult.partial:
        return AppColors.amber;
      case DpTestResult.notTested:
      case DpTestResult.tbc:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dpTestProvider(caseId).notifier);
    final titleParts = [
      if (test.testNo != null) '#${test.testNo}',
      if (test.testName != null && test.testName!.isNotEmpty) test.testName!,
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titleParts.join('  '),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kDpColor),
                  ),
                ),
                if (test.system != null && test.system!.isNotEmpty)
                  Text(test.system!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => notifier.delete(test.testId),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Result',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Wrap(
              spacing: 6,
              children: [
                for (final r in DpTestResult.values)
                  ChoiceChip(
                    label: Text(r.label, style: const TextStyle(fontSize: 11)),
                    selected: test.result == r,
                    onSelected: (_) => notifier.setResult(test.testId, r),
                    selectedColor: _resultColor(r).withValues(alpha: 0.22),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Finding',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Wrap(
              spacing: 6,
              children: [
                for (final c in DpFindingCategory.values)
                  ChoiceChip(
                    label: Text(c.label, style: const TextStyle(fontSize: 11)),
                    selected: test.findingCategory == c,
                    onSelected: (_) =>
                        notifier.setFindingCategory(test.testId, c),
                    selectedColor: (c == DpFindingCategory.critical
                            ? AppColors.coral
                            : _kDpColor)
                        .withValues(alpha: 0.20),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _FlagToggle(
                  label: 'WCF tested',
                  value: test.wcfTested,
                  onChanged: (v) => notifier.setWcfTested(test.testId, v),
                ),
                const SizedBox(width: 12),
                _FlagToggle(
                  label: 'Carried forward',
                  value: test.carriedForward,
                  onChanged: (v) =>
                      notifier.setCarriedForward(test.testId, v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagToggle extends StatelessWidget {
  const _FlagToggle(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
