// lib/features/pi/screens/pi_opinion_screen.dart
//
// P&I / Expert — Opinion & Conclusions register. Discrete reasoned opinion
// points, each with its basis and the GPN-EXPT / cl.3 qualifiers (outside
// expertise; not concluded for want of data). Feeds the expert-report Opinion
// section later. Distinct from the factual Causation module.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/pi_models.dart';
import '../providers/pi_opinion_provider.dart';

const _kPiColor = Color(0xFF3B4A8C);

class PiOpinionScreen extends ConsumerWidget {
  const PiOpinionScreen({super.key, required this.caseId});
  final String caseId;

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final headingCtrl = TextEditingController();
    final opinionCtrl = TextEditingController();
    final basisCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add opinion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: headingCtrl,
                decoration: const InputDecoration(
                    labelText: 'Heading (optional)'),
              ),
              TextField(
                controller: opinionCtrl,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Opinion',
                    hintText: 'Reasoned, appropriately reserved…'),
              ),
              TextField(
                controller: basisCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Basis — assumptions / material facts'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved == true && opinionCtrl.text.trim().isNotEmpty) {
      await ref.read(piOpinionProvider(caseId).notifier).add(
            opinionCtrl.text.trim(),
            heading: headingCtrl.text.trim().isEmpty
                ? null
                : headingCtrl.text.trim(),
            basis: basisCtrl.text.trim().isEmpty ? null : basisCtrl.text.trim(),
          );
      if (context.mounted) showSavedToast(context, label: 'Opinion added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(piOpinionProvider(caseId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Opinion & Conclusions')),
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
        data: (opinions) {
          if (opinions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No opinions yet.\nEach opinion is a discrete, reasoned '
                  'conclusion with its basis and qualifiers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [for (final o in opinions) _OpinionCard(caseId: caseId, opinion: o)],
          );
        },
      ),
    );
  }
}

class _OpinionCard extends ConsumerWidget {
  const _OpinionCard({required this.caseId, required this.opinion});
  final String caseId;
  final PiOpinionModel opinion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(piOpinionProvider(caseId).notifier);
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
                if (opinion.heading != null && opinion.heading!.isNotEmpty)
                  Expanded(
                    child: Text(opinion.heading!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _kPiColor)),
                  )
                else
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => notifier.delete(opinion.id),
                ),
              ],
            ),
            Text(opinion.opinionText, style: const TextStyle(fontSize: 14)),
            if (opinion.basis != null && opinion.basis!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Basis: ${opinion.basis}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: const Text('Outside expertise',
                      style: TextStyle(fontSize: 11)),
                  selected: opinion.outsideExpertise,
                  onSelected: (v) =>
                      notifier.setQualifiers(opinion.id, outsideExpertise: v),
                  selectedColor: AppColors.amber.withValues(alpha: 0.22),
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('Not concluded (want of data)',
                      style: TextStyle(fontSize: 11)),
                  selected: opinion.notConcluded,
                  onSelected: (v) =>
                      notifier.setQualifiers(opinion.id, notConcluded: v),
                  selectedColor: AppColors.amber.withValues(alpha: 0.22),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
