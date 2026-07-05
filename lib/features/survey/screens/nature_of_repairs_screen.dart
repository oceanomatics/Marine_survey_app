// lib/features/survey/screens/nature_of_repairs_screen.dart
//
// "Nature of the Repairs" — new case-screen section, positioned just
// before "Repair Periods" (report builder §11.1, ahead of §11.2 Repair
// Periods), per surveyor direction (5 July 2026): a handful of early
// indicator questions (drydocking, assured's plan, further inspections,
// parts lead time, foreseeable difficulties — each with a comment box
// shown once ticked) plus a free addable "anticipated sequence of
// repairs" bullet list. Usable from the very first attendance, before any
// repair period exists — "if we attend a vessel right after the
// incident... there are at least some indications of where this claim is
// going, and the extent of the general services that are predictably
// needed."

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/nature_of_repairs_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/addable_bullet_list.dart';

class NatureOfRepairsScreen extends ConsumerStatefulWidget {
  const NatureOfRepairsScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<NatureOfRepairsScreen> createState() =>
      _NatureOfRepairsScreenState();
}

class _NatureOfRepairsScreenState
    extends ConsumerState<NatureOfRepairsScreen> {
  final _drydockingCtrl = TextEditingController();
  final _assuredPlanCtrl = TextEditingController();
  final _furtherInspectionsCtrl = TextEditingController();
  final _partsLeadTimeCtrl = TextEditingController();
  final _foreseeableDifficultiesCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _drydockingCtrl.dispose();
    _assuredPlanCtrl.dispose();
    _furtherInspectionsCtrl.dispose();
    _partsLeadTimeCtrl.dispose();
    _foreseeableDifficultiesCtrl.dispose();
    super.dispose();
  }

  void _syncOne(TextEditingController ctrl, String? value) {
    final v = value ?? '';
    if (ctrl.text.isEmpty && v.isNotEmpty) {
      ctrl.text = v;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
  }

  void _debounced(VoidCallback save) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), save);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(natureOfRepairsProvider(widget.caseId));
    final notifier = ref.read(natureOfRepairsProvider(widget.caseId).notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Nature of the Repairs')),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          _syncOne(_drydockingCtrl, data.drydockingComment);
          _syncOne(_assuredPlanCtrl, data.assuredPlanComment);
          _syncOne(_furtherInspectionsCtrl, data.furtherInspectionsComment);
          _syncOne(_partsLeadTimeCtrl, data.partsLeadTimeComment);
          _syncOne(_foreseeableDifficultiesCtrl,
              data.foreseeableDifficultiesComment);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Early indications of the likely repair scope — useful '
                'from the first attendance, before any repair period has '
                'been recorded.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 12),
              _QuestionCard(
                question: 'Does the repair require drydocking of the vessel?',
                value: data.drydockingRequired,
                commentCtrl: _drydockingCtrl,
                hint: 'Describe the drydocking requirement…',
                onToggle: (v) => notifier.setDrydocking(v, data.drydockingComment),
                onCommentChanged: (t) => _debounced(
                    () => notifier.setDrydocking(data.drydockingRequired, t)),
              ),
              _QuestionCard(
                question:
                    "Has the Assured already formulated a plan for the repairs?",
                value: data.assuredPlanFormulated,
                commentCtrl: _assuredPlanCtrl,
                hint: "Describe the Assured's plan…",
                onToggle: (v) =>
                    notifier.setAssuredPlan(v, data.assuredPlanComment),
                onCommentChanged: (t) => _debounced(() =>
                    notifier.setAssuredPlan(data.assuredPlanFormulated, t)),
              ),
              _QuestionCard(
                question:
                    'Are any further inspections planned prior to the repairs?',
                value: data.furtherInspectionsPlanned,
                commentCtrl: _furtherInspectionsCtrl,
                hint: 'Describe the planned inspection(s)…',
                onToggle: (v) => notifier.setFurtherInspections(
                    v, data.furtherInspectionsComment),
                onCommentChanged: (t) => _debounced(() =>
                    notifier.setFurtherInspections(
                        data.furtherInspectionsPlanned, t)),
              ),
              _QuestionCard(
                question: 'Are there parts with a long lead time?',
                value: data.partsLongLeadTime,
                commentCtrl: _partsLeadTimeCtrl,
                hint: 'Describe the parts and expected lead time…',
                onToggle: (v) =>
                    notifier.setPartsLeadTime(v, data.partsLeadTimeComment),
                onCommentChanged: (t) => _debounced(() =>
                    notifier.setPartsLeadTime(data.partsLongLeadTime, t)),
              ),
              _QuestionCard(
                question: 'Are there any foreseeable difficulties?',
                value: data.foreseeableDifficulties,
                commentCtrl: _foreseeableDifficultiesCtrl,
                hint: 'Describe the anticipated difficulties…',
                onToggle: (v) => notifier.setForeseeableDifficulties(
                    v, data.foreseeableDifficultiesComment),
                onCommentChanged: (t) => _debounced(() =>
                    notifier.setForeseeableDifficulties(
                        data.foreseeableDifficulties, t)),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.all(14),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Anticipated Sequence of Repairs',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text(
                                'Free list, presented as a bullet list in the '
                                'report — e.g. temporary repairs, permanent '
                                'repairs, class attendance, sea trials…',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                      AddableBulletList(
                        label: 'SEQUENCE OF REPAIRS',
                        items: data.sequenceItems
                            .map((e) =>
                                BulletListItem(id: e.itemId, text: e.text))
                            .toList(),
                        emptyText:
                            'No items added. Tap Add to record an anticipated step.',
                        onAdd: () => showAddBulletItemDialog(
                          context,
                          title: 'Add Repair Step',
                          hintText: 'Describe the anticipated step…',
                          onAdd: notifier.addSequenceItem,
                        ),
                        onRemove: notifier.removeSequenceItem,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.commentCtrl,
    required this.hint,
    required this.onToggle,
    required this.onCommentChanged,
  });

  final String question;
  final bool value;
  final TextEditingController commentCtrl;
  final String hint;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onCommentChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(question,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Switch(
                value: value,
                onChanged: onToggle,
                activeThumbColor: AppColors.midBlue,
              ),
            ],
          ),
          if (value) ...[
            const SizedBox(height: 4),
            TextField(
              controller: commentCtrl,
              onChanged: onCommentChanged,
              maxLines: null,
              minLines: 2,
              style: const TextStyle(fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12.5),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.midBlue, width: 1.5)),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
