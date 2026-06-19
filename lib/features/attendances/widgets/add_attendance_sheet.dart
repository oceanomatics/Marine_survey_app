// lib/features/attendances/widgets/add_attendance_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_model.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../../shared/theme/app_theme.dart';

const _kColor = Color(0xFFBF7E3A);

// ── Simple data holder for a new attendee typed inline ───────────────────

class AttendeeEntry {
  AttendeeEntry({required this.name, this.role, this.company});
  String name;
  AttendeeRole? role;
  String? company;
}

// ── Sheet ─────────────────────────────────────────────────────────────────

class AddAttendanceSheet extends StatefulWidget {
  const AddAttendanceSheet({
    super.key,
    required this.onSave,
    this.previousAttendees = const [],
  });

  final List<AttendeeModel> previousAttendees;

  /// Callback: base fields + (enabled previous attendees, new inline entries).
  final Future<void> Function(
    AttendanceType type,
    DateTime? date,
    String? location,
    String? surveyorName,
    VesselStatus? vesselStatus,
    String? summary,
    List<AttendeeModel> enabledPrevious,
    List<AttendeeEntry> newAttendees,
  ) onSave;

  @override
  State<AddAttendanceSheet> createState() => _AddAttendanceSheetState();
}

class _AddAttendanceSheetState extends State<AddAttendanceSheet> {
  AttendanceType _type = AttendanceType.initial;
  DateTime? _date;
  VesselStatus? _vesselStatus;

  final _locationCtrl  = TextEditingController();
  final _surveyorCtrl  = TextEditingController(text: 'Pierre-Louis Constant');
  final _summaryCtrl   = TextEditingController();

  // Previous attendees: attendeeId → enabled toggle
  late final Map<String, bool> _previousEnabled;

  // New attendees typed inline this session
  final List<_InlineAttendee> _newEntries = [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default all previous attendees to enabled (present)
    _previousEnabled = {
      for (final a in widget.previousAttendees) a.attendeeId: true,
    };
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _surveyorCtrl.dispose();
    _summaryCtrl.dispose();
    for (final e in _newEntries) {
      e.nameCtrl.dispose();
      e.companyCtrl.dispose();
    }
    super.dispose();
  }

  String? _val(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      locale: const Locale('en', 'AU'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _addNewEntry() {
    setState(() => _newEntries.add(_InlineAttendee()));
  }

  void _removeNewEntry(int i) {
    setState(() {
      _newEntries[i].nameCtrl.dispose();
      _newEntries[i].companyCtrl.dispose();
      _newEntries.removeAt(i);
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final enabledPrevious = widget.previousAttendees
          .where((a) => _previousEnabled[a.attendeeId] == true)
          .toList();

      final newAttendees = _newEntries
          .where((e) => e.nameCtrl.text.trim().isNotEmpty)
          .map((e) => AttendeeEntry(
                name: e.nameCtrl.text.trim(),
                role: e.role,
                company: e.companyCtrl.text.trim().isEmpty
                    ? null
                    : e.companyCtrl.text.trim(),
              ))
          .toList();

      await widget.onSave(
        _type,
        _date,
        _val(_locationCtrl),
        _val(_surveyorCtrl),
        _vesselStatus,
        _val(_summaryCtrl),
        enabledPrevious,
        newAttendees,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      color: _kColor, size: 17),
                ),
                const SizedBox(width: 10),
                const Text('Add Attendance',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 18),

              // ── Type ────────────────────────────────────────────────
              const _Label('Attendance type'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: AttendanceType.values.map((t) {
                  final selected = _type == t;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kColor.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected ? _kColor : AppColors.border,
                            width: selected ? 1.5 : 1),
                      ),
                      child: Text(
                        t.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? _kColor
                                : AppColors.textSecondary),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // ── Date ────────────────────────────────────────────────
              const _Label('Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _date != null
                          ? DateFormat('dd/MM/yyyy').format(_date!)
                          : 'Select date',
                      style: TextStyle(
                          fontSize: 14,
                          color: _date != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ── Location ─────────────────────────────────────────────
              _field('Location', _locationCtrl,
                  hint: 'e.g. Port of Brisbane, Drydock No. 3'),
              const SizedBox(height: 12),

              // ── Vessel status ─────────────────────────────────────────
              const _Label('Vessel status'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<VesselStatus?>(
                  value: _vesselStatus,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('— Not specified —',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textTertiary)),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— Not specified —',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary))),
                    ...VesselStatus.values.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                        )),
                  ],
                  onChanged: (v) => setState(() => _vesselStatus = v),
                ),
              ),
              const SizedBox(height: 12),

              // ── Surveyor ─────────────────────────────────────────────
              _field('Attending surveyor', _surveyorCtrl,
                  hint: 'Name of attending surveyor'),
              const SizedBox(height: 16),

              // ── Attendees ─────────────────────────────────────────────
              _AttendeesSection(
                previousAttendees: widget.previousAttendees,
                previousEnabled: _previousEnabled,
                newEntries: _newEntries,
                onToggle: (id, val) =>
                    setState(() => _previousEnabled[id] = val),
                onAddEntry: _addNewEntry,
                onRemoveEntry: _removeNewEntry,
                onRoleChanged: (i, role) =>
                    setState(() => _newEntries[i].role = role),
              ),
              const SizedBox(height: 14),

              // ── Summary ───────────────────────────────────────────────
              _field('Brief summary', _summaryCtrl,
                  hint:
                      'Conditions found, work observed, follow-up items…',
                  maxLines: 4),
              const SizedBox(height: 18),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Attendance',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        labelStyle: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

// ── Inline attendee state (mutable, not immutable) ───────────────────────

class _InlineAttendee {
  final nameCtrl    = TextEditingController();
  final companyCtrl = TextEditingController();
  AttendeeRole? role;
}

// ── Attendees section widget ──────────────────────────────────────────────

class _AttendeesSection extends StatelessWidget {
  const _AttendeesSection({
    required this.previousAttendees,
    required this.previousEnabled,
    required this.newEntries,
    required this.onToggle,
    required this.onAddEntry,
    required this.onRemoveEntry,
    required this.onRoleChanged,
  });

  final List<AttendeeModel> previousAttendees;
  final Map<String, bool> previousEnabled;
  final List<_InlineAttendee> newEntries;
  final void Function(String attendeeId, bool val) onToggle;
  final VoidCallback onAddEntry;
  final void Function(int index) onRemoveEntry;
  final void Function(int index, AttendeeRole? role) onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final hasPrevious = previousAttendees.isNotEmpty;
    final hasNew = newEntries.isNotEmpty;

    if (!hasPrevious && !hasNew) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Attendees present'),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onAddEntry,
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Add attendee', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kColor,
              side: const BorderSide(color: _kColor),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Attendees present'),
        const SizedBox(height: 8),

        // ── Previous attendees with toggle ──────────────────────────
        if (hasPrevious)
          Builder(builder: (_) {
            final sorted = [...previousAttendees]..sort((a, b) =>
                (a.roleType?.sortOrder ?? 99)
                    .compareTo(b.roleType?.sortOrder ?? 99));
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < sorted.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.border),
                    _PreviousAttendeeRow(
                      attendee: sorted[i],
                      enabled:
                          previousEnabled[sorted[i].attendeeId] ?? true,
                      onToggle: (val) =>
                          onToggle(sorted[i].attendeeId, val),
                    ),
                  ],
                ],
              ),
            );
          }),

        if (hasPrevious && hasNew) const SizedBox(height: 8),

        // ── New attendees typed this session ─────────────────────────
        for (int i = 0; i < newEntries.length; i++) ...[
          _NewAttendeeRow(
            entry: newEntries[i],
            onRemove: () => onRemoveEntry(i),
            onRoleChanged: (role) => onRoleChanged(i, role),
          ),
          const SizedBox(height: 8),
        ],

        OutlinedButton.icon(
          onPressed: onAddEntry,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Add attendee', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kColor,
            side: const BorderSide(color: _kColor),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ── Previous attendee row with switch ─────────────────────────────────────

class _PreviousAttendeeRow extends StatelessWidget {
  const _PreviousAttendeeRow({
    required this.attendee,
    required this.enabled,
    required this.onToggle,
  });

  final AttendeeModel attendee;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attendee.fullName,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary),
              ),
              if (attendee.roleType != null || attendee.company != null)
                Text(
                  [
                    if (attendee.roleType != null)
                      attendee.roleType!.label,
                    if (attendee.company != null) attendee.company!,
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? AppColors.textSecondary
                          : AppColors.textTertiary),
                ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onToggle,
          activeThumbColor: _kColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ── New attendee inline entry ─────────────────────────────────────────────

class _NewAttendeeRow extends StatelessWidget {
  const _NewAttendeeRow({
    required this.entry,
    required this.onRemove,
    required this.onRoleChanged,
  });

  final _InlineAttendee entry;
  final VoidCallback onRemove;
  final ValueChanged<AttendeeRole?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: entry.nameCtrl,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Full name',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide:
                        const BorderSide(color: _kColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.textTertiary),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: DropdownButton<AttendeeRole?>(
                  value: entry.role,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  hint: const Text('Role',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textTertiary)),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— Role —',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary))),
                    ...AttendeeRole.values.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                        )),
                  ],
                  onChanged: onRoleChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: entry.companyCtrl,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Company / org.',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide:
                        const BorderSide(color: _kColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Shared label ──────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary));
  }
}
