// lib/features/attendances/widgets/edit_attendees_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../parties/models/party_model.dart';
import '../../parties/providers/parties_provider.dart';
import '../../../shared/theme/app_theme.dart';

const _kColor = Color(0xFFBF7E3A);

class EditAttendeesSheet extends ConsumerStatefulWidget {
  const EditAttendeesSheet({
    super.key,
    required this.caseId,
    required this.attendanceId,
    required this.initialAttendees,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onReorder,
  });

  final String caseId;
  final String attendanceId;
  final List<AttendeeModel> initialAttendees;
  final Future<AttendeeModel> Function(AttendeeModel) onAdd;
  final Future<void> Function(AttendeeModel) onUpdate;
  final Future<void> Function(String attendeeId) onDelete;
  /// Persists a new drag-to-reorder order — full list of attendee ids for
  /// this attendance, in the new display order.
  final Future<void> Function(List<String> orderedAttendeeIds) onReorder;

  @override
  ConsumerState<EditAttendeesSheet> createState() =>
      _EditAttendeesSheetState();
}

class _EditAttendeesSheetState extends ConsumerState<EditAttendeesSheet> {
  late List<AttendeeModel> _attendees;

  final _nameCtrl    = TextEditingController();
  final _companyCtrl = TextEditingController();
  AttendeeTitle? _newTitle;
  AttendeeRole? _newRole;
  bool _adding = false;
  String? _error;
  // Attendee↔Parties link (14 July 2026 walkthrough: "Yes, definitely
  // build it — important"). Set when picked from the Parties list below;
  // cleared to offer "add to Parties" instead for a brand-new person.
  String? _pickedPartyId;

  @override
  void initState() {
    super.initState();
    _attendees = [...widget.initialAttendees]..sort(_compareAttendees);
  }

  /// Manual drag order (sort_order) wins; falls back to the old fixed
  /// role-based order only for rows predating migration 015.
  int _compareAttendees(AttendeeModel a, AttendeeModel b) {
    if (a.sortOrder != null && b.sortOrder != null) {
      return a.sortOrder!.compareTo(b.sortOrder!);
    }
    return (a.roleType?.sortOrder ?? 99).compareTo(b.roleType?.sortOrder ?? 99);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      final item = _attendees.removeAt(oldIndex);
      _attendees.insert(newIndex, item);
    });
    await widget.onReorder(_attendees.map((a) => a.attendeeId).toList());
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

  Future<void> _update(AttendeeModel a) async {
    await widget.onUpdate(a);
    setState(() {
      final i = _attendees.indexWhere((x) => x.attendeeId == a.attendeeId);
      if (i != -1) _attendees[i] = a;
    });
  }

  // Pick an existing Parties/Stakeholder contact to prefill from, instead
  // of re-typing someone already on file (14 July 2026 walkthrough).
  void _pickFromParty(AssuredContactModel c) {
    setState(() {
      _nameCtrl.text = c.fullName;
      _companyCtrl.text = c.company ?? '';
      _pickedPartyId = c.contactId;
    });
  }

  Future<void> _offerAddToParties(String name) async {
    if (!mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Parties?'),
        content: Text(
          '$name isn\'t in this case\'s Parties/Stakeholder register yet. '
          'Add them now so they don\'t need to be re-entered later?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add to Parties')),
        ],
      ),
    );
    if (add != true || !mounted) return;
    await ref.read(assuredContactsProvider(widget.caseId).notifier).add(
          caseId: widget.caseId,
          fullName: name,
          company:
              _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
          stakeholderGroup: StakeholderGroup.other,
        );
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _adding = true; _error = null; });
    try {
      final pickedParty = _pickedPartyId;
      final created = await widget.onAdd(AttendeeModel(
        attendeeId:   '',
        caseId:       widget.caseId,
        fullName:     name,
        attendanceId: widget.attendanceId,
        title:        _newTitle,
        roleType:     _newRole,
        company:      _companyCtrl.text.trim().isEmpty
            ? null
            : _companyCtrl.text.trim(),
        representingPartyId: pickedParty,
      ));
      setState(() {
        _attendees.add(created);
        _attendees.sort(_compareAttendees);
        _nameCtrl.clear();
        _companyCtrl.clear();
        _newTitle = null;
        _newRole = null;
        _pickedPartyId = null;
      });
      // Only offer for someone not already picked from the Parties list.
      if (pickedParty == null) await _offerAddToParties(name);
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
              else ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Drag the handle to reorder.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic)),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: _reorder,
                    itemCount: _attendees.length,
                    itemBuilder: (context, i) => Column(
                      key: ValueKey(_attendees[i].attendeeId),
                      children: [
                        if (i > 0)
                          const Divider(
                              height: 1, color: AppColors.border),
                        _AttendeeRow(
                          index: i,
                          attendee: _attendees[i],
                          onDelete: () => _delete(_attendees[i]),
                          onUpdate: _update,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Add new attendee form ─────────────────────────────────
              const _Label('Add attendee'),
              const SizedBox(height: 8),

              _PartyPickerRow(caseId: widget.caseId, onPick: _pickFromParty),

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
                    // Title + name on one row
                    Row(children: [
                      SizedBox(
                        width: 88,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<AttendeeTitle?>(
                            value: _newTitle,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            hint: const Text('Title',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary)),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('—',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppColors.textTertiary))),
                              ...AttendeeTitle.values.map((t) =>
                                  DropdownMenuItem(
                                    value: t,
                                    child: Text(t.label,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                  )),
                            ],
                            onChanged: (v) =>
                                setState(() => _newTitle = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: _inputDeco('Full name'),
                        ),
                      ),
                    ]),
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

// ── Party picker (Attendee↔Parties link, 14 July 2026 walkthrough) ─────────
// Empty when the case has no Parties/Stakeholder contacts yet, so it never
// adds clutter to cases where none have been entered.

class _PartyPickerRow extends ConsumerWidget {
  const _PartyPickerRow({required this.caseId, required this.onPick});
  final String caseId;
  final ValueChanged<AssuredContactModel> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(assuredContactsProvider(caseId)).value ?? [];
    if (contacts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pick from Parties',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: contacts.map((c) {
              return GestureDetector(
                onTap: () => onPick(c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    c.company != null
                        ? '${c.fullName} — ${c.company}'
                        : c.fullName,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textPrimary),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Attendee row with delete button ───────────────────────────────────────

class _AttendeeRow extends StatefulWidget {
  const _AttendeeRow({
    required this.index,
    required this.attendee,
    required this.onDelete,
    required this.onUpdate,
  });
  final int index;
  final AttendeeModel attendee;
  final Future<void> Function() onDelete;
  final Future<void> Function(AttendeeModel) onUpdate;

  @override
  State<_AttendeeRow> createState() => _AttendeeRowState();
}

class _AttendeeRowState extends State<_AttendeeRow> {
  bool _deleting = false;
  bool _editing = false;
  bool _saving = false;
  late final _editNameCtrl =
      TextEditingController(text: widget.attendee.fullName);
  late AttendeeTitle? _editTitle = widget.attendee.title;

  @override
  void dispose() {
    _editNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final name = _editNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onUpdate(widget.attendee.copyWith(
          fullName: name, title: _editTitle, clearTitle: _editTitle == null));
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.attendee.roleType?.label ??
        widget.attendee.rankPosition;
    final company = widget.attendee.company;

    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<AttendeeTitle?>(
                value: _editTitle,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                isDense: true,
                hint: const Text('—', style: TextStyle(fontSize: 12)),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('—', style: TextStyle(fontSize: 12))),
                  ...AttendeeTitle.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label, style: const TextStyle(fontSize: 12)))),
                ],
                onChanged: (v) => setState(() => _editTitle = v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _editNameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (_) => _saveEdit(),
            ),
          ),
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.check, size: 18, color: _kColor),
                  onPressed: _saveEdit,
                  tooltip: 'Save',
                ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 18, color: AppColors.textTertiary),
            onPressed: () => setState(() => _editing = false),
            tooltip: 'Cancel',
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        ReorderableDragStartListener(
          index: widget.index,
          child: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.drag_indicator,
                size: 18, color: AppColors.textTertiary),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _editing = true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.attendee.prefix} ${widget.attendee.fullName}',
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
