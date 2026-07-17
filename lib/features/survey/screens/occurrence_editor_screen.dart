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
import '../providers/attendees_provider.dart';
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
import '../../../shared/widgets/save_bar.dart';

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
  String? _reportedByAttendeeId;
  bool _saving = false;
  bool _generating = false;
  bool _sorting = false;
  // Persistent unsaved-changes indicator surfaced through the standard
  // bottom SaveBar (same convention as parties/vessel screens) instead of the
  // easy-to-miss app-bar Save button (16 July 2026 occurrence/cue UX sweep,
  // item 2).
  bool _hasChanges = false;
  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

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
    _reportedByAttendeeId   = occ.reportedByAttendeeId;
    // Listeners attached only after seeding the fields so the initial load
    // doesn't count as a change.
    for (final c in [
      _titleCtrl, _locationCtrl, _narrativeCtrl, _aftermathPortCtrl,
    ]) {
      c.addListener(_markChanged);
    }
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
      _hasChanges = true;
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
        reportedByAttendeeId:   _reportedByAttendeeId,
        ownersStatedCause:       occ.ownersStatedCause,
        ownersStatedCauseSource: occ.ownersStatedCauseSource,
        thirdPartyFindings:      occ.thirdPartyFindings,
        surveyorsAssessment:     occ.surveyorsAssessment,
        certaintyLevel:          occ.certaintyLevel,
      );
      await ref
          .read(damageProvider(widget.caseId).notifier)
          .updateOccurrence(updated);
      if (mounted) {
        setState(() => _hasChanges = false);
        showSavedToast(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Occurrence-tagged, non-ignored cues scoped to this occurrence.
  List<SurveyorNote> _occurrenceCues() =>
      (ref.read(surveyorNotesProvider(widget.caseId)).value ?? [])
          .where((n) =>
              n.caseSection == CaseSection.occurrence &&
              n.linkedToType == occurrenceLinkType &&
              n.linkedToId == widget.occurrence.occurrenceId &&
              n.priority != CuePriority.ignored)
          .toList();

  /// Role descriptor of the "Reported by" attendee, for the narrative opening
  /// ("It was reported by the [role] that …"). Null → prompt defaults to
  /// "vessel's Master".
  String? _reporterRole() {
    if (_reportedByAttendeeId == null) return null;
    final attendees = ref.read(attendeesProvider(widget.caseId)).value ?? [];
    for (final a in attendees) {
      if (a.attendeeId == _reportedByAttendeeId) {
        return a.roleType?.label ?? 'reporting party';
      }
    }
    return null;
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
          <String>[];
      final cues = _occurrenceCues();
      List<String> phase(OccurrencePhase p) => cues
          .where((n) => n.occurrencePhase == p)
          .map((n) => n.content)
          .toList();
      final unsorted = cues
          .where((n) => n.occurrencePhase == null)
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
              reporterRole: _reporterRole(),
              beforeCues: phase(OccurrencePhase.before),
              incidentCues: phase(OccurrencePhase.incident),
              aftermathCues: phase(OccurrencePhase.aftermath),
              // Damage components + any still-unsorted cues ride along as
              // supplementary context so nothing is lost from the draft.
              damageItems: [...damageItems, ...unsorted],
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

  /// AI pre-sort: classify every still-unsorted occurrence cue into a phase
  /// (docs/occurrence_narrative_spec.md). "Surveyor picks, AI pre-sorts" — the
  /// result is only a suggestion the surveyor can override with each cue's
  /// 3-way phase selector.
  Future<void> _sortCues() async {
    if (_sorting) return;
    final unsorted =
        _occurrenceCues().where((n) => n.occurrencePhase == null).toList();
    if (unsorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unsorted cues to sort.')),
      );
      return;
    }
    setState(() => _sorting = true);
    try {
      final notifier = ref.read(surveyorNotesProvider(widget.caseId).notifier);
      final title = _titleCtrl.text.trim().isEmpty
          ? widget.occurrence.title
          : _titleCtrl.text.trim();
      await ref.read(aiTasksProvider.notifier).run(
            label: 'Sorting ${unsorted.length} occurrence '
                'cue${unsorted.length == 1 ? '' : 's'}',
            caseId: widget.caseId,
            estimate: Duration(seconds: 3 * unsorted.length),
            action: () async {
              for (final n in unsorted) {
                final phaseStr = await ClaudeApi.classifyOccurrenceCuePhase(
                  cueText: n.content,
                  occurrenceTitle: title,
                  caseId: widget.caseId,
                );
                await notifier.editNote(
                  n.id,
                  content: n.content,
                  natureOfContent: n.natureOfContent,
                  evidentiaryWeight: n.evidentiaryWeight,
                  origin: n.origin,
                  caseSection: n.caseSection,
                  occurrencePhase: OccurrencePhase.fromValue(phaseStr),
                  priority: n.priority,
                );
              }
              return '';
            },
          );
      if (mounted) showSavedToast(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sort failed: $e'),
              backgroundColor: AppColors.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _sorting = false);
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
      // Save moved off the app bar into the standard SaveBar, which doubles as
      // the unsaved-changes indicator (16 July 2026 occurrence/cue UX sweep).
      bottomNavigationBar: SaveBar(
        visible: _hasChanges,
        saving: _saving,
        onSave: _save,
        label: 'Save occurrence',
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
                  onTap: () => setState(() {
                    _dateTime = null;
                    _hasChanges = true;
                  }),
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
        _buildReportedByPicker(),
        _DropdownField(
          label: 'Vessel Status at Casualty',
          value: _vesselStatusAtCasualty,
          options: _kVesselStatusOptions,
          onChanged: (v) => setState(() {
            _vesselStatusAtCasualty = v;
            _hasChanges = true;
          }),
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
                onChanged: (v) => setState(() {
                  _aftermathStatus = v;
                  _hasChanges = true;
                }),
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

  /// "Reported by" attendee picker (docs/occurrence_narrative_spec.md) —
  /// the chosen attendee's role fills the "[role]" slot in the narrative
  /// opening. Lists the case's attendees; empty-state nudges the surveyor to
  /// the Attendances screen.
  Widget _buildReportedByPicker() {
    final attendeesAsync = ref.watch(attendeesProvider(widget.caseId));
    final attendees = attendeesAsync.value ?? const <AttendeeModel>[];
    // If the stored reporter is no longer an attendee, don't feed the
    // Dropdown a value it has no item for (asserts otherwise).
    final ids = attendees.map((a) => a.attendeeId).toSet();
    final value = ids.contains(_reportedByAttendeeId) ? _reportedByAttendeeId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text('Reported By',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        if (attendees.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No attendees recorded yet — add them on the Attendances '
              'screen to attribute the account.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          )
        else
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
                ...attendees.map((a) => DropdownMenuItem(
                      value: a.attendeeId,
                      child: Text(
                        a.roleType != null
                            ? '${a.fullName} — ${a.roleType!.label}'
                            : a.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                      ),
                    )),
              ],
              onChanged: (v) => setState(() {
                _reportedByAttendeeId = v;
                _hasChanges = true;
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildNarrativeTab() {
    final occId = widget.occurrence.occurrenceId;
    final itemScope = CueItemScope(
      linkedToType: occurrenceLinkType,
      linkedToId: occId,
    );
    // Unsorted count decides whether that bucket starts open (mirrors
    // RepairPeriodScopedCuesScreen). Recreating the panel State when the
    // empty/non-empty boundary is crossed re-evaluates initiallyExpanded.
    final cues = _occurrenceCues();
    final unsortedCount =
        cues.where((n) => n.occurrencePhase == null).length;

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
        Row(
          children: [
            const Expanded(
              child: Text('Context Cues — by narrative phase',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3)),
            ),
            if (unsortedCount > 0)
              GestureDetector(
                onTap: _sorting ? null : _sortCues,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                  ),
                  child: _sorting
                      ? const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.amber))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome_outlined,
                              size: 11, color: AppColors.amber),
                          SizedBox(width: 4),
                          Text('AI Sort',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amber)),
                        ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'A cue forks into one of three phases — the narrative is drafted '
          'from them in order. "AI Sort" pre-sorts unsorted cues; you can '
          'override any cue\'s phase.',
          style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 10),

        // Unsorted bucket — freshly-added / AI-extracted cues awaiting a phase.
        CueSectionCard(
          title: 'Unsorted',
          hint: 'Cues not yet assigned to a phase.',
          child: ContextCuesPanel(
            key: ValueKey('occ-unsorted-${unsortedCount > 0}'),
            caseId: widget.caseId,
            section: CaseSection.occurrence,
            itemScope: itemScope,
            occurrencePhaseScope: const OccurrencePhaseScope.unsorted(),
            initiallyExpanded: unsortedCount > 0,
          ),
        ),
        const SizedBox(height: 12),

        // One bucket per phase, in narrative order.
        for (final phase in OccurrencePhase.ordered) ...[
          CueSectionCard(
            title: phase.label,
            hint: phase.hint,
            child: ContextCuesPanel(
              caseId: widget.caseId,
              section: CaseSection.occurrence,
              itemScope: itemScope,
              occurrencePhaseScope: OccurrencePhaseScope.forPhase(phase),
              initiallyExpanded: false,
            ),
          ),
          const SizedBox(height: 12),
        ],
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
