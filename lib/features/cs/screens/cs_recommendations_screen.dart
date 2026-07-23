// lib/features/cs/screens/cs_recommendations_screen.dart
//
// C&S §1.13 gating recommendations — the punch-list that must be closed
// before approval. Add manually or via the "UNSATISFACTORY → recommendation"
// flow on the inspection screen. Open/closed toggle drives the gate later.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/cs_models.dart';
import '../providers/cs_recommendation_provider.dart';

const _kCsColor = Color(0xFF1E6B5A);

class CsRecommendationsScreen extends ConsumerWidget {
  const CsRecommendationsScreen({super.key, required this.caseId});
  final String caseId;

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add recommendation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe the required action…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await ref.read(csRecommendationProvider(caseId).notifier).add(text);
      if (context.mounted) showSavedToast(context, label: 'Recommendation added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(csRecommendationProvider(caseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Recommendations')),
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
        data: (recs) {
          if (recs.isEmpty) {
            return const Center(
              child: Text('No recommendations yet',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          final open = recs
              .where((r) => r.status == CsRecommendationStatus.open)
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('$open open of ${recs.length}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              for (final r in recs) _RecTile(caseId: caseId, rec: r),
            ],
          );
        },
      ),
    );
  }
}

class _RecTile extends ConsumerWidget {
  const _RecTile({required this.caseId, required this.rec});
  final String caseId;
  final CsRecommendationModel rec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closed = rec.status == CsRecommendationStatus.closed;
    final notifier = ref.read(csRecommendationProvider(caseId).notifier);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            closed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: closed ? AppColors.green : AppColors.textSecondary,
          ),
          onPressed: () => notifier.setStatus(
              rec.id,
              closed
                  ? CsRecommendationStatus.open
                  : CsRecommendationStatus.closed),
        ),
        title: Text(
          rec.text.isEmpty ? '(no text)' : rec.text,
          style: TextStyle(
            decoration: closed ? TextDecoration.lineThrough : null,
            color: closed ? AppColors.textSecondary : null,
          ),
        ),
        subtitle: rec.sourceItemId != null
            ? const Text('From an unsatisfactory inspection item',
                style: TextStyle(fontSize: 11))
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: AppColors.textSecondary,
          onPressed: () => notifier.delete(rec.id),
        ),
      ),
    );
  }
}
