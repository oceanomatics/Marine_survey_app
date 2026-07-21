// lib/features/cs/screens/cs_inspection_screen.dart
//
// C&S — AHTS inspection screen (Module A, first cut). Renders the shared
// template skeleton grouped by section; each gradable item carries a grade
// selector that upserts a cs_inspection_item. Section headers show the
// auto-derived rating. Marking an item UNSATISFACTORY offers to spawn a
// linked §1.13 recommendation.
//
// This is the section-by-section capture surface; polish (voice remark,
// photo-per-item) lands in a later pass.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/cs_models.dart';
import '../providers/cs_template_provider.dart';
import '../providers/cs_inspection_provider.dart';
import '../providers/cs_recommendation_provider.dart';

const _kCsColor = Color(0xFF1E6B5A);

class CsInspectionScreen extends ConsumerWidget {
  const CsInspectionScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(csTemplateItemsProvider('ahts'));
    final inspection = ref.watch(csInspectionProvider(caseId)).value ?? const [];

    // template_item_id -> current inspection item
    final byTemplate = <String, CsInspectionItemModel>{
      for (final i in inspection)
        if (i.templateItemId != null) i.templateItemId!: i,
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('C&S Inspection')),
      body: templateAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (template) {
          if (template.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No AHTS template seeded yet.\nRun migration 063b in Supabase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          // Grades per section (for the header rollup badge).
          final gradesBySection = <String, List<CsGrade?>>{};
          for (final t in template) {
            if (!t.gradeApplicable) continue;
            gradesBySection
                .putIfAbsent(t.section, () => [])
                .add(byTemplate[t.id]?.grade);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: template.length,
            itemBuilder: (context, index) {
              final t = template[index];
              if (!t.gradeApplicable) {
                final rating = deriveSectionRating(
                    gradesBySection[t.section] ?? const []);
                return _SectionHeader(item: t, rating: rating);
              }
              return _ItemRow(
                caseId: caseId,
                template: t,
                current: byTemplate[t.id],
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.item, required this.rating});
  final CsTemplateItemModel item;
  final CsSectionRating rating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.refNo ?? item.section}  ${item.label}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15, color: _kCsColor),
            ),
          ),
          _RatingBadge(rating: rating),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});
  final CsSectionRating rating;

  Color get _color {
    switch (rating) {
      case CsSectionRating.good:
        return AppColors.green;
      case CsSectionRating.satisfactoryWithIssues:
        return AppColors.amber;
      case CsSectionRating.unsatisfactory:
        return AppColors.coral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rating.label,
        style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.caseId,
    required this.template,
    required this.current,
  });
  final String caseId;
  final CsTemplateItemModel template;
  final CsInspectionItemModel? current;

  Future<void> _setGrade(BuildContext context, WidgetRef ref, CsGrade grade) async {
    final notifier = ref.read(csInspectionProvider(caseId).notifier);
    CsInspectionItemModel item;
    if (current == null) {
      item = await notifier.addItem(
          templateItemId: template.id,
          grade: grade,
          sortOrder: template.sortOrder);
    } else {
      await notifier.setGrade(current!.id, grade);
      item = current!.copyWith(grade: grade);
    }
    if (grade == CsGrade.unsatisfactory && context.mounted) {
      _offerRecommendation(context, ref, item);
    }
  }

  void _offerRecommendation(
      BuildContext context, WidgetRef ref, CsInspectionItemModel item) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${template.label}" marked unsatisfactory'),
          action: SnackBarAction(
            label: 'Add recommendation',
            onPressed: () async {
              await ref
                  .read(csRecommendationProvider(caseId).notifier)
                  .addFromItem(item, text: template.label);
              if (context.mounted) {
                showSavedToast(context, label: 'Recommendation added');
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = current?.grade;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (template.refNo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(template.refNo!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                Expanded(
                  child: Text(template.label,
                      style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final g in CsGrade.values)
                  ChoiceChip(
                    label: Text(g.label,
                        style: const TextStyle(fontSize: 12)),
                    selected: grade == g,
                    onSelected: (_) => _setGrade(context, ref, g),
                    selectedColor: _gradeColor(g).withValues(alpha: 0.22),
                    labelStyle: TextStyle(
                        color: grade == g
                            ? _gradeColor(g)
                            : AppColors.textSecondary,
                        fontWeight:
                            grade == g ? FontWeight.w700 : FontWeight.w500),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(CsGrade g) {
    switch (g) {
      case CsGrade.good:
        return AppColors.green;
      case CsGrade.satisfactory:
        return AppColors.teal;
      case CsGrade.unsatisfactory:
        return AppColors.coral;
      case CsGrade.na:
        return AppColors.textSecondary;
    }
  }
}
