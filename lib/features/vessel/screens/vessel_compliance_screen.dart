// lib/features/vessel/screens/vessel_compliance_screen.dart
//
// Merged Certificates + Class & Statutory screen (full push route).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/cases/models/case_model.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../models/class_condition_model.dart';
import '../models/psc_deficiency_model.dart';
import '../providers/certificates_provider.dart';
import '../providers/class_conditions_provider.dart';
import '../providers/psc_deficiencies_provider.dart';
import '../providers/vessel_provider.dart';
import '../widgets/add_certificate_sheet.dart';
import '../widgets/certificate_card.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

class VesselComplianceScreen extends ConsumerStatefulWidget {
  const VesselComplianceScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<VesselComplianceScreen> createState() =>
      _VesselComplianceScreenState();
}

class _VesselComplianceScreenState
    extends ConsumerState<VesselComplianceScreen> {
  // Vessel-level editable fields
  ClassStatus? _classStatus;
  DateTime?    _drydockDate;
  final _drydockYardCtrl = TextEditingController();
  DateTime?    _pscDate;
  PscResult?   _pscResult;
  final _pscSummaryCtrl  = TextEditingController();
  IspsStatus?  _ispsStatus;
  bool         _ismIncident   = false;
  bool         _classIncident = false;

  bool _populated = false;
  bool _hasChanges = false;
  bool _saving     = false;

  void _populate(VesselModel v) {
    if (_populated) return;
    _populated         = true;
    _classStatus       = v.classStatus;
    _drydockDate       = v.lastDrydockDate;
    _drydockYardCtrl.text = v.lastDrydockYard ?? '';
    _pscDate           = v.pscLastInspection;
    _pscResult         = v.pscLastResult;
    _pscSummaryCtrl.text  = v.pscSummary ?? '';
    _ispsStatus        = v.ispsStatus;
    _ismIncident       = v.ismIncidentReported   ?? false;
    _classIncident     = v.classIncidentReported ?? false;
  }

  void _markChanged() => setState(() => _hasChanges = true);

  Future<void> _save(String vesselId) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .saveVessel(vesselId: vesselId, fields: {
        'class_status':            _classStatus?.value,
        'last_drydock_date':       _drydockDate?.toIso8601String().split('T').first,
        'last_drydock_yard':       _drydockYardCtrl.text.trim().isEmpty
            ? null : _drydockYardCtrl.text.trim(),
        'psc_last_inspection':     _pscDate?.toIso8601String().split('T').first,
        'psc_last_result':         _pscResult?.value,
        'psc_summary':             _pscSummaryCtrl.text.trim().isEmpty
            ? null : _pscSummaryCtrl.text.trim(),
        'isps_status':             _ispsStatus?.value,
        'ism_incident_reported':   _ismIncident,
        'class_incident_reported': _classIncident,
      });
      setState(() => _hasChanges = false);
    } catch (e, st) {
      if (mounted) {
        showError(context, 'Save failed: $e', error: e, stack: st, tag: 'Compliance');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _drydockYardCtrl.dispose();
    _pscSummaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vesselAsync = ref.watch(vesselForCaseProvider(widget.caseId));
    final vessel = vesselAsync.value;
    if (vessel != null) _populate(vessel);

    final vesselId = vessel?.vesselId;
    final certs    = ref.watch(certificatesProvider(widget.caseId)).value ?? [];
    final conditions = vesselId != null
        ? (ref.watch(classConditionsProvider(vesselId)).value ?? [])
        : <ClassConditionModel>[];
    final deficiencies = vesselId != null
        ? (ref.watch(pscDeficienciesProvider(vesselId)).value ?? [])
        : <PscDeficiencyModel>[];
    final occurrences = ref.watch(damageProvider(widget.caseId)).value?.occurrences ?? [];
    final primaryOcc  = occurrences.where((o) => o.isPrimary).firstOrNull
        ?? occurrences.firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Certificates & Class'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_hasChanges && vesselId != null)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: () => _save(vesselId),
                    child: const Text('Save',
                        style: TextStyle(
                            color: AppColors.midBlue,
                            fontWeight: FontWeight.w700)),
                  ),
        ],
      ),
      body: vessel == null
          ? const Center(child: Text('No vessel linked to this case.'))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── CERTIFICATES ────────────────────────────────────────────
                _SectionHeader(
                  title: 'Certificates',
                  icon: Icons.verified_outlined,
                  color: AppColors.purple,
                  action: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddCertificateSheet(
                        caseId: widget.caseId,
                        onSave: (fields) async {
                          await ref
                              .read(certificatesProvider(widget.caseId).notifier)
                              .addCertificate(fields);
                        },
                      ),
                    ),
                  ),
                ),
                if (certs.isEmpty)
                  const _Empty('No certificates added yet')
                else
                  ...certs.map((cert) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CertificateCard(
                          cert: cert,
                          onEdit: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => AddCertificateSheet(
                              caseId: widget.caseId,
                              existing: cert,
                              onSave: (fields) async {
                                await ref
                                    .read(certificatesProvider(widget.caseId)
                                        .notifier)
                                    .updateCertificate(fields);
                              },
                            ),
                          ),
                          onDelete: () async {
                            await ref
                                .read(certificatesProvider(widget.caseId)
                                    .notifier)
                                .deleteCertificate(cert.certId);
                          },
                        ),
                      )),

                const SizedBox(height: 20),

                // ── CLASSIFICATION ──────────────────────────────────────────
                _SectionHeader(
                  title: 'Classification',
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF4A7FA5),
                ),
                const SizedBox(height: 8),
                const _FieldLabel('Class Status'),
                _ChipRow<ClassStatus>(
                  values: ClassStatus.values,
                  selected: _classStatus,
                  label: (s) => s.label,
                  onChanged: (v) { setState(() { _classStatus = v; _hasChanges = true; }); },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: _FieldLabel('Class Conditions'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => _showConditionSheet(
                          context, vesselId!, occurrences),
                    ),
                  ],
                ),
                if (conditions.isEmpty)
                  const _Empty('No conditions recorded')
                else
                  ...conditions.map((c) => _ConditionTile(
                        condition: c,
                        occurrences: occurrences,
                        onEdit: () => _showConditionSheet(
                            context, vesselId!, occurrences, existing: c),
                        onDelete: () => ref
                            .read(classConditionsProvider(vesselId!).notifier)
                            .delete(c.conditionId),
                      )),

                const SizedBox(height: 20),

                // ── DRYDOCKING ──────────────────────────────────────────────
                _SectionHeader(
                  title: 'Drydocking',
                  icon: Icons.anchor_outlined,
                  color: AppColors.amber,
                ),
                const SizedBox(height: 8),
                _DatePickerRow(
                  label: 'Last drydock date',
                  date: _drydockDate,
                  onChanged: (d) { setState(() { _drydockDate = d; _hasChanges = true; }); },
                ),
                TextField(
                  controller: _drydockYardCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Drydock yard',
                    hintText: 'e.g. Sembcorp Marine, Singapore',
                    isDense: true,
                  ),
                  onChanged: (_) => _markChanged(),
                ),

                const SizedBox(height: 20),

                // ── PORT STATE CONTROL ──────────────────────────────────────
                _SectionHeader(
                  title: 'Port State Control',
                  icon: Icons.policy_outlined,
                  color: AppColors.coral,
                ),
                const SizedBox(height: 8),
                _DatePickerRow(
                  label: 'Last inspection date',
                  date: _pscDate,
                  onChanged: (d) { setState(() { _pscDate = d; _hasChanges = true; }); },
                ),
                const SizedBox(height: 8),
                const _FieldLabel('Inspection result'),
                _ChipRow<PscResult>(
                  values: PscResult.values,
                  selected: _pscResult,
                  label: (r) => r.label,
                  onChanged: (v) { setState(() { _pscResult = v; _hasChanges = true; }); },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pscSummaryCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'PSC summary',
                    hintText: 'Brief summary of inspection findings (populated by Equasis import)',
                    isDense: true,
                  ),
                  onChanged: (_) => _markChanged(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: _FieldLabel('Deficiencies')),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () =>
                          _showDeficiencySheet(context, vesselId!),
                    ),
                  ],
                ),
                if (deficiencies.isEmpty)
                  const _Empty('No deficiencies recorded')
                else
                  ...deficiencies.map((d) => _DeficiencyTile(
                        deficiency: d,
                        onEdit: () =>
                            _showDeficiencySheet(context, vesselId!, existing: d),
                        onDelete: () => ref
                            .read(pscDeficienciesProvider(vesselId!).notifier)
                            .delete(d.deficiencyId),
                      )),

                const SizedBox(height: 20),

                // ── ISPS ────────────────────────────────────────────────────
                _SectionHeader(
                  title: 'ISPS',
                  icon: Icons.security_outlined,
                  color: AppColors.midBlue,
                ),
                const SizedBox(height: 8),
                _ChipRow<IspsStatus>(
                  values: IspsStatus.values,
                  selected: _ispsStatus,
                  label: (s) => s.label,
                  onChanged: (v) { setState(() { _ispsStatus = v; _hasChanges = true; }); },
                ),

                const SizedBox(height: 20),

                // ── INCIDENTS ───────────────────────────────────────────────
                _SectionHeader(
                  title: 'Incidents',
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.coral,
                ),
                if (primaryOcc != null) ...[
                  const SizedBox(height: 8),
                  _OccurrenceCard(occurrence: primaryOcc),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('ISM incident reported to flag/class',
                      style: TextStyle(fontSize: 13)),
                  subtitle: _ismIncident && primaryOcc != null
                      ? const Text('Reported — ISM incident report should be on file',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary))
                      : null,
                  value: _ismIncident,
                  onChanged: (v) => setState(() { _ismIncident = v; _hasChanges = true; }),
                  activeThumbColor: AppColors.midBlue,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Reported to classification society',
                      style: TextStyle(fontSize: 13)),
                  subtitle: _classIncident
                      ? const Text(
                          'Confirmed — check for class conditions linked to this occurrence',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary))
                      : null,
                  value: _classIncident,
                  onChanged: (v) => setState(() { _classIncident = v; _hasChanges = true; }),
                  activeThumbColor: AppColors.midBlue,
                ),

                // auto-hint: if any class condition is linked to primary occ, flag it
                if (_classIncident == false &&
                    primaryOcc != null &&
                    conditions.any((c) =>
                        c.occurrenceRelated && c.occurrenceId == primaryOcc.occurrenceId))
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'A class condition is linked to the primary occurrence — consider toggling "Reported to class".',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.amber.withValues(alpha: 0.9)),
                        ),
                      ),
                    ]),
                  ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  void _showConditionSheet(
    BuildContext ctx,
    String vesselId,
    List<OccurrenceModel> occurrences, {
    ClassConditionModel? existing,
  }) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassConditionSheet(
        vesselId: vesselId,
        occurrences: occurrences,
        existing: existing,
        onSave: (ref_, desc, expiry, occRelated, occId) async {
          if (existing == null) {
            await ref.read(classConditionsProvider(vesselId).notifier).add(
                  vesselId: vesselId,
                  reference: ref_,
                  description: desc,
                  expiryDate: expiry,
                  occurrenceRelated: occRelated,
                  occurrenceId: occId,
                );
          } else {
            await ref
                .read(classConditionsProvider(vesselId).notifier)
                .updateCondition(
                  existing.conditionId,
                  reference: ref_,
                  description: desc,
                  expiryDate: expiry,
                  occurrenceRelated: occRelated,
                  occurrenceId: occId,
                );
          }
        },
      ),
    );
  }

  void _showDeficiencySheet(BuildContext ctx, String vesselId,
      {PscDeficiencyModel? existing}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PscDeficiencySheet(
        vesselId: vesselId,
        existing: existing,
        onSave: (code, desc, action, rectified) async {
          if (existing == null) {
            await ref.read(pscDeficienciesProvider(vesselId).notifier).add(
                  vesselId: vesselId,
                  code: code,
                  description: desc,
                  actionRequired: action,
                  rectified: rectified,
                );
          } else {
            await ref
                .read(pscDeficienciesProvider(vesselId).notifier)
                .updateDeficiency(
                  existing.deficiencyId,
                  code: code,
                  description: desc,
                  actionRequired: action,
                  rectified: rectified,
                );
          }
        },
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.action,
  });
  final String title;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.8)),
      ),
      if (action != null) action!,
    ]);
  }
}

// ── Generic chip row ───────────────────────────────────────────────────────────

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: values.map((v) {
        final active = v == selected;
        return ChoiceChip(
          label: Text(label(v),
              style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : AppColors.textSecondary)),
          selected: active,
          selectedColor: AppColors.midBlue,
          backgroundColor: AppColors.surface,
          side: BorderSide(
              color: active ? AppColors.midBlue : AppColors.border),
          onSelected: (_) => onChanged(active ? null : v),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

// ── Date picker row ────────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.onChanged,
  });
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  String _fmt(DateTime? d) => d == null
      ? 'Not set'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
      ),
      TextButton(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) onChanged(d);
        },
        child: Text(_fmt(date),
            style: const TextStyle(
                fontSize: 13, color: AppColors.midBlue)),
      ),
      if (date != null)
        IconButton(
          icon: const Icon(Icons.clear, size: 16,
              color: AppColors.textTertiary),
          onPressed: () => onChanged(null),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
    ]);
  }
}

// ── Field label ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary));
}

// ── Empty hint ─────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(message,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic)),
      );
}

// ── Condition tile ─────────────────────────────────────────────────────────────

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.condition,
    required this.occurrences,
    required this.onEdit,
    required this.onDelete,
  });
  final ClassConditionModel condition;
  final List<OccurrenceModel> occurrences;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final linkedOcc = condition.occurrenceId != null
        ? occurrences.where((o) => o.occurrenceId == condition.occurrenceId)
            .firstOrNull
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (condition.reference != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.midBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(condition.reference!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.midBlue)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  condition.description ?? 'No description',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.textTertiary),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.textTertiary),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.event_outlined,
                  size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('Expires ${_fmtDate(condition.expiryDate)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
              if (linkedOcc != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.link, size: 12, color: AppColors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    linkedOcc.title ??
                        'Occurrence #${linkedOcc.occurrenceNo}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.amber),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Deficiency tile ────────────────────────────────────────────────────────────

class _DeficiencyTile extends StatelessWidget {
  const _DeficiencyTile({
    required this.deficiency,
    required this.onEdit,
    required this.onDelete,
  });
  final PscDeficiencyModel deficiency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: deficiency.rectified ? AppColors.success : AppColors.coral,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deficiency.code != null)
                  Text(deficiency.code!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary)),
                Text(deficiency.description ?? 'No description',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
                if (deficiency.actionRequired != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Action: ${deficiency.actionRequired!}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 2),
                Text(
                  deficiency.rectified ? '✓ Rectified' : 'Outstanding',
                  style: TextStyle(
                      fontSize: 11,
                      color: deficiency.rectified
                          ? AppColors.success
                          : AppColors.coral,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textTertiary),
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.textTertiary),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ]),
      ),
    );
  }
}

// ── Occurrence preview card ────────────────────────────────────────────────────

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({required this.occurrence});
  final OccurrenceModel occurrence;

  String _fmtDate(DateTime? d) => d == null
      ? 'Date unknown'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_note_outlined,
              size: 14, color: AppColors.coral),
          const SizedBox(width: 6),
          Text('Primary occurrence',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.coral.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text(
          occurrence.title ?? 'Occurrence #${occurrence.occurrenceNo}',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        Text(
          '${_fmtDate(occurrence.dateTime)}'
          '${occurrence.location != null ? " · ${occurrence.location}" : ""}',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textTertiary),
        ),
        if (occurrence.briefDescription != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(occurrence.briefDescription!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }
}

// ── Class condition sheet ──────────────────────────────────────────────────────

class _ClassConditionSheet extends StatefulWidget {
  const _ClassConditionSheet({
    required this.vesselId,
    required this.occurrences,
    required this.onSave,
    this.existing,
  });
  final String vesselId;
  final List<OccurrenceModel> occurrences;
  final ClassConditionModel? existing;
  final Future<void> Function(
    String? reference,
    String? description,
    DateTime? expiryDate,
    bool occurrenceRelated,
    String? occurrenceId,
  ) onSave;

  @override
  State<_ClassConditionSheet> createState() => _ClassConditionSheetState();
}

class _ClassConditionSheetState extends State<_ClassConditionSheet> {
  final _refCtrl  = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _expiry;
  bool      _occRelated = false;
  String?   _occId;
  bool      _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _refCtrl.text  = e.reference  ?? '';
    _descCtrl.text = e.description ?? '';
    _expiry        = e.expiryDate;
    _occRelated    = e.occurrenceRelated;
    _occId         = e.occurrenceId;
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing == null
                ? 'Add Class Condition'
                : 'Edit Class Condition',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference number',
              hintText: 'e.g. MC-2024-001',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Brief description of the condition',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          _DatePickerRow(
            label: 'Expiry date',
            date: _expiry,
            onChanged: (d) => setState(() => _expiry = d),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Related to an occurrence',
                style: TextStyle(fontSize: 13)),
            value: _occRelated,
            onChanged: (v) => setState(() {
              _occRelated = v;
              if (!v) _occId = null;
            }),
            activeThumbColor: AppColors.midBlue,
          ),
          if (_occRelated && widget.occurrences.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _occId,
              decoration: const InputDecoration(
                labelText: 'Related occurrence',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: widget.occurrences.map((o) => DropdownMenuItem(
                    value: o.occurrenceId,
                    child: Text(
                        o.title ?? 'Occurrence #${o.occurrenceNo}',
                        overflow: TextOverflow.ellipsis),
                  )).toList(),
              onChanged: (v) => setState(() => _occId = v),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                try {
                  await widget.onSave(
                    _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
                    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                    _expiry,
                    _occRelated,
                    _occRelated ? _occId : null,
                  );
                  if (mounted) Navigator.pop(context);
                } catch (e, st) {
                  if (mounted) {
                    showError(context, 'Save failed: $e',
                        error: e, stack: st, tag: 'Condition');
                  }
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.midBlue),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── PSC deficiency sheet ───────────────────────────────────────────────────────

class _PscDeficiencySheet extends StatefulWidget {
  const _PscDeficiencySheet({
    required this.vesselId,
    required this.onSave,
    this.existing,
  });
  final String vesselId;
  final PscDeficiencyModel? existing;
  final Future<void> Function(
    String? code,
    String? description,
    String? actionRequired,
    bool rectified,
  ) onSave;

  @override
  State<_PscDeficiencySheet> createState() => _PscDeficiencySheetState();
}

class _PscDeficiencySheetState extends State<_PscDeficiencySheet> {
  final _codeCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _actionCtrl = TextEditingController();
  bool  _rectified  = false;
  bool  _saving     = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _codeCtrl.text   = e.code ?? '';
    _descCtrl.text   = e.description ?? '';
    _actionCtrl.text = e.actionRequired ?? '';
    _rectified       = e.rectified;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing == null
                ? 'Add PSC Deficiency'
                : 'Edit Deficiency',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Deficiency code',
              hintText: 'e.g. 10115',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'e.g. Lifesaving appliances — inadequate maintenance',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _actionCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Action required',
              hintText: 'e.g. Rectify within 3 months',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Rectified',
                style: TextStyle(fontSize: 13)),
            value: _rectified,
            onChanged: (v) => setState(() => _rectified = v),
            activeThumbColor: AppColors.success,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                try {
                  await widget.onSave(
                    _codeCtrl.text.trim().isEmpty   ? null : _codeCtrl.text.trim(),
                    _descCtrl.text.trim().isEmpty   ? null : _descCtrl.text.trim(),
                    _actionCtrl.text.trim().isEmpty ? null : _actionCtrl.text.trim(),
                    _rectified,
                  );
                  if (mounted) Navigator.pop(context);
                } catch (e, st) {
                  if (mounted) {
                    showError(context, 'Save failed: $e',
                        error: e, stack: st, tag: 'PSCDeficiency');
                  }
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.midBlue),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }
}
