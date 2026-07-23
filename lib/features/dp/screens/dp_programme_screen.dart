// lib/features/dp/screens/dp_programme_screen.dart
//
// DP FMEA — the trial-programme overview (one record per case): the overall
// result, operating modes, the rules/IMCA basis, and the programme revision.
// Text fields commit on submit; the result is a chip row.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/dp_models.dart';
import '../providers/dp_programme_provider.dart';

const _kDpColor = Color(0xFF0E7C86);

class DpProgrammeScreen extends ConsumerStatefulWidget {
  const DpProgrammeScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<DpProgrammeScreen> createState() => _DpProgrammeScreenState();
}

class _DpProgrammeScreenState extends ConsumerState<DpProgrammeScreen> {
  final _modes = TextEditingController();
  final _rules = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _modes.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _seed(DpProgrammeModel? p) {
    if (_seeded) return;
    _modes.text = p?.operatingModes ?? '';
    _rules.text = p?.applicableRules ?? '';
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dpProgrammeProvider(widget.caseId));
    final notifier = ref.read(dpProgrammeProvider(widget.caseId).notifier);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('DP Trials — Programme')),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          _seed(p);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              const Text('Overall result',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: _kDpColor)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in DpOverallResult.values)
                    ChoiceChip(
                      label: Text(r.label, style: const TextStyle(fontSize: 12)),
                      selected: p?.overallResult == r,
                      onSelected: (_) => notifier.setOverallResult(r),
                      selectedColor: (r == DpOverallResult.nonCompliant
                              ? AppColors.coral
                              : r == DpOverallResult.compliantWithFindings
                                  ? AppColors.amber
                                  : AppColors.green)
                          .withValues(alpha: 0.22),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _modes,
                decoration: const InputDecoration(
                  labelText: 'Operating modes',
                  hintText: 'e.g. 4-split, 2-split',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) async {
                  await notifier.setOperatingModes(v);
                  if (context.mounted) showSavedToast(context);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rules,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Applicable rules / IMCA basis',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) async {
                  await notifier.setApplicableRules(v);
                  if (context.mounted) showSavedToast(context);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Revision: ',
                      style: TextStyle(color: AppColors.textSecondary)),
                  Text('${p?.revision ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Bump revision'),
                    onPressed: () =>
                        notifier.setRevision((p?.revision ?? 0) + 1),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
