// lib/features/attendances/widgets/edit_attendees_sheet.dart

import 'package:flutter/material.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../../shared/theme/app_theme.dart';

const _kColor = Color(0xFFBF7E3A);

class EditAttendeesSheet extends StatefulWidget {
  const EditAttendeesSheet({
    super.key,
    required this.caseId,
    required this.attendanceId,
    required this.initialAttendees,
    required this.onAdd,
    required this.onDelete,
  });

  final String caseId;
  final String attendanceId;
  final List<AttendeeModel> initialAttendees;
  final Future<AttendeeModel> Function(AttendeeModel) onAdd;
  final Future<void> Function(String attendeeId) onDelete;

  @override
  State<EditAttendeesSheet> createState() => _EditAttendeesSheetState();
}

class _EditAttendeesSheetState extends State<EditAttendeesSheet> {
  late List<AttendeeModel> _attendees;

  final _nameCtrl    = TextEditingController();
  final _companyCtrl = TextEditingController();
  AttendeeRole? _newRole;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _attendees = [...widget.initialAttendees]
      ..sort((a, b) =>
          (a.roleType?.sortOrder ?? 99)
              .compareTo(b.roleType?.sortOrder ?? 99));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(AttendeeModel a) async {
    await widget.onDelete(a.attendeeId);
    setState(() =>
        _attendees.removeWhere((x) => x.attendeeId == a.attendeeId));
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _adding = true; _error = null; });
    try {
      final created = await widget.onAdd(AttendeeModel(
        attendeeId:   '',
        caseId:       widget.caseId,
        fullName:     name,
        attendanceId: widget.attendanceId,
        roleType:     _newRole,
        company:      _companyCtrl.text.trim().isEmpty
            ? null
            : _companyCtrl.text.trim(),
      ));
      setState(() {
        _attendees.add(created);
        _attendees.sort((a, b) =>
            (a.roleType?.sortOrder ?? 99)
                .compareTo(b.roleType?.sortOrder ?? 99));
        _nameCtrl.clear();
        _companyCtrl.clear();
        _newRole = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_outline,
                      color: _kColor, size: 17),
                ),
                const SizedBox(width: 10),
                const Text('Edit Attendees',
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

              // ── Current attendees ────────────────────────────────────
              if (_attendees.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text('No attendees recorded yet.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic)),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _attendees.length; i++) ...[
                        if (i > 0)
                          const Divider(
                              height: 1, color: AppColors.border),
                        _AttendeeRow(
                          attendee: _attendees[i],
                          onDelete: () => _delete(_attendees[i]),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── Add new attendee form ─────────────────────────────────
              const _Label('Add attendee'),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _kColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    // Name
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: _inputDeco('Full name'),
                    ),
                    const SizedBox(height: 8),
                    // Role + company on one row
                    Row(children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<AttendeeRole?>(
                            value: _newRole,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            hint: const Text('Role',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary)),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('— Role —',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppColors.textTertiary))),
                              ...AttendeeRole.values.map((r) =>
                                  DropdownMenuItem(
                                    value: r,
                                    child: Text(r.label,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                  )),
                            ],
                            onChanged: (v) =>
                                setState(() => _newRole = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _companyCtrl,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary),
                          decoration: _inputDeco('Company / org.'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.error)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _adding ? null : _add,
                        icon: _adding
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.person_add_outlined,
                                size: 16),
                        label: const Text('Add',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        filled: true,
        fillColor: Colors.white,
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
      );
}

// ── Attendee row with delete button ───────────────────────────────────────

class _AttendeeRow extends StatefulWidget {
  const _AttendeeRow({required this.attendee, required this.onDelete});
  final AttendeeModel attendee;
  final Future<void> Function() onDelete;

  @override
  State<_AttendeeRow> createState() => _AttendeeRowState();
}

class _AttendeeRowState extends State<_AttendeeRow> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.attendee.roleType?.label ??
        widget.attendee.rankPosition;
    final company = widget.attendee.company;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.attendee.fullName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
              ),
              if (role != null || company != null)
                Text(
                  [if (role != null) role, if (company != null) company]
                      .join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        _deleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textTertiary))
            : IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textTertiary),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove attendee?'),
                      content: Text(
                          'Remove ${widget.attendee.fullName} from this attendance?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !mounted) return;
                  setState(() => _deleting = true);
                  await widget.onDelete();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove',
              ),
      ]),
    );
  }
}

// ── Label ─────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));
}
