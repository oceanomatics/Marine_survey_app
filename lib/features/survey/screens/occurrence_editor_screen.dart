// lib/features/survey/screens/occurrence_editor_screen.dart
//
// Full-screen occurrence editor (TODO.md §3.7, 8 July 2026 review, row 15)
// — replaces the old popup/sheet editor, which was too long/awkward for
// an occurrence with any real amount of data. Two tabs: Details (the
// structured hard fields) and Narrative (free-text background + the
// occurrence's own scoped context cues + an AI Draft convenience).
//
// Editing only — creation stays on the lightweight AddOccurrenceSheet
// quick-create flow (occurrence_screen.dart), since per-occurrence cue
// scoping needs a real occurrence_id to attach to.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../surveyor_notes/providers/surveyor_notes_provider.dart';
import '../../../core/api/claude_api.dart';
import '../../ai_tasks/providers/ai_tasks_provider.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

const _kVesselStatusOptions = {
  'at_sea':            'At Sea',
  'in_port_at_anchor': 'In Port / At Anchor',
  'maintenance':       'Undergoing Maintenance',
  'manoeuvring':       'Manoeuvring',
};

const _kAftermathOptions = {
  'own_power':                 'Own Power',
  'tug_only':                  'Tug Only',
  'tug_and_pilot':             'Tug and Pilot',
  'tug_pilot_lines_gangway':   'Tug, Pilot, Lines & Gangway',
  'towed':                     'Towed',
  'proceeded_with_operations': 'Proceeded with Operations',
};

class OccurrenceEditorScreen extends ConsumerStatefulWidget {
  const OccurrenceEditorScreen({
    super.key,
    required this.caseId,
    required this.occurrence,
  });
  final String caseId;
  final OccurrenceModel occurrence;

  @override
  ConsumerState<OccurrenceEditorScreen> createState() =>
      _OccurrenceEditorScreenState();
}

class _OccurrenceEditorScreenState extends ConsumerState<OccurrenceEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _narrativeCtrl = TextEditingController();
  final _aftermathPortCtrl = TextEditingController();
  DateTime? _dateTime;
  String? _vesselStatusAtCasualty;
  String? _aftermathStatus;
  bool _saving = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final occ = widget.occurrence;
    _titleCtrl.text        = occ.title ?? '';
    _locationCtrl.text     = occ.location ?? '';
    _narrativeCtrl.text    = occ.briefDescription ?? '';
    _aftermathPortCtrl.text = occ.aftermathPort ?? '';
    _dateTime               = occ.dateTime;
    _vesselStatusAtCasualty = occ.vesselStatusAtCasualty;
    _aftermathStatus        = occ.aftermathStatus;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _narrativeCtrl.dispose();
    _aftermathPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('en', 'AU'),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? DateTime.now()),
    );
    if (!mounted) return;
    setState(() {
      _dateTime = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? 0, time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Occurrence title is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final occ = widget.occurrence;
      final updated = OccurrenceModel(
        occurrenceId:        occ.occurrenceId,
        caseId:              occ.caseId,
        occurrenceNo:        occ.occurrenceNo,
        isPrimary:           occ.isPrimary,
        title:               _titleCtrl.text.trim(),
        dateTime:            _dateTime,
        location:            _locationCtrl.text.trim().isEmpty
            ? null : _locationCtrl.text.trim(),
        briefDescription:    _narrativeCtrl.text.trim().isEmpty
            ? null : _narrativeCtrl.text.trim(),
        backgroundNarrative: occ.backgroundNarrative,
        chronology:          occ.chronology,
        causeType:           occ.causeType,
        allegationType:      occ.allegationType,
        causeAgreement:      occ.causeAgreement,
        causeNarrative:      occ.causeNarrative,
        ismReported:         occ.ismReported,
        createdAt:           occ.createdAt,
        vesselStatusAtCasualty: _vesselStatusAtCasualty,
        aftermathStatus:        _aftermathStatus,
        aftermathPort:          _aftermathPortCtrl.text.trim().isEmpty
            ? null : _aftermathPortCtrl.text.trim(),
      );
      await ref
          .read(damageProvider(widget.caseId).notifier)
          .updateOccurrence(updated);
      if (mounted) showSavedToast(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateNarrative() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final vessel = ref.read(vesselForCaseProvider(widget.caseId)).value;
      final caseModel = ref.read(caseProvider(widget.caseId)).value;
      final damage = ref.read(damageProvider(widget.caseId)).value;
      final damageItems = damage
              ?.itemsForOccurrence(widget.occurrence.occurrenceId)
              .map((d) => d.componentName)
              .toList() ??
          const <String>[];
      final cues = (ref.read(surveyorNotesProvider(widget.caseId)).value ?? [])
          .where((n) =>
              n.caseSection == CaseSection.occurrence &&
              n.linkedToType == occurrenceLinkType &&
              n.linkedToId == widget.occurrence.occurrenceId)
          .map((n) => n.content)
          .toList();

      final text = await ref.read(aiTasksProvider.notifier).run(
            label: 'Drafting occurrence narrative',
            caseId: widget.caseId,
            caseLabel: vessel?.name,
            estimate: const Duration(seconds: 20),
            action: () => ClaudeApi.draftOccurrenceNarrative(
              vesselName: vessel?.name ?? 'the vessel',
              occurrenceDate:
                  _dateTime != null ? _formatDateTime(_dateTime!) : 'unknown',
              occurrenceLocation: _locationCtrl.text.trim().isEmpty
                  ? 'unknown'
                  : _locationCtrl.text.trim(),
              occurrenceTitle: _titleCtrl.text.trim().isEmpty
                  ? (widget.occurrence.title ??
                      'Occurrence ${widget.occurrence.occurrenceNo}')
                  : _titleCtrl.text.trim(),
              damageItems: [...damageItems, ...cues],
              interviewTranscript: null,
              reportFormat: caseModel?.outputFormat?.value ?? 'abl',
            ),
          );
      if (mounted) _narrativeCtrl.text = text;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI draft failed: $e'),
              backgroundColor: AppColors.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Text(
          widget.occurrence.title ?? 'Occurrence ${widget.occurrence.occurrenceNo}',
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Details'), Tab(text: 'Narrative')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildDetailsTab(), _buildNarrativeTab()],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SurveyField(
          label: 'Occurrence Title *',
          controller: _titleCtrl,
          hint: 'e.g. Main diesel generator No.3 — connecting rod cap failure',
          important: true,
        ),
        const Text('Date & Time of Occurrence',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Text(
                _dateTime != null
                    ? _formatDateTime(_dateTime!)
                    : 'Select date and time',
                style: TextStyle(
                  fontSize: 14,
                  color: _dateTime != null
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontWeight:
                      _dateTime != null ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              const Spacer(),
              if (_dateTime != null)
                GestureDetector(
                  onTap: () => setState(() => _dateTime = null),
                  child: const Icon(Icons.clear,
                      size: 16, color: AppColors.textTertiary),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        SurveyField(
          label: 'Location',
          controller: _locationCtrl,
          hint: 'e.g. 12 NM off Onslow, Western Australia',
        ),
        _DropdownField(
          label: 'Vessel Status at Casualty',
          value: _vesselStatusAtCasualty,
          options: _kVesselStatusOptions,
          onChanged: (v) => setState(() => _vesselStatusAtCasualty = v),
        ),
        const SizedBox(height: 14),
        const Text('Aftermath',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DropdownField(
                label: 'What happened after the casualty?',
                value: _aftermathStatus,
                options: _kAftermathOptions,
                onChanged: (v) => setState(() => _aftermathStatus = v),
              ),
              const SizedBox(height: 10),
              SurveyField(
                label: 'Port (if applicable)',
                controller: _aftermathPortCtrl,
                hint: 'e.g. Fremantle',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNarrativeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Narrative',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3)),
            ),
            GestureDetector(
              onTap: _generating ? null : _generateNarrative,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: _generating
                    ? const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.amber),
                      )
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 11, color: AppColors.amber),
                        SizedBox(width: 4),
                        Text('AI Draft',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.amber)),
                      ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SurveyField(
          label: '',
          controller: _narrativeCtrl,
          hint: 'Background, sequence of events, owner\'s account…',
          maxLines: 12,
        ),
        const SizedBox(height: 20),
        const Text('Context Cues',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        ContextCuesPanel(
          caseId: widget.caseId,
          section: CaseSection.occurrence,
          itemScope: CueItemScope(
            linkedToType: occurrenceLinkType,
            linkedToId: widget.occurrence.occurrenceId,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Reusable labelled dropdown (string key/value options) ──────────────────

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String?>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('— Not specified —',
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('— Not specified —',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textTertiary))),
              ...options.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
