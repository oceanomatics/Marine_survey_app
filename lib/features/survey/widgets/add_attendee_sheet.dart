// lib/features/survey/widgets/add_attendee_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendees_provider.dart';
import '../../parties/models/party_model.dart';
import '../../parties/providers/parties_provider.dart';
import '../../vessel/widgets/survey_field.dart';
import '../../../shared/theme/app_theme.dart';

class AddAttendeeSheet extends ConsumerStatefulWidget {
  const AddAttendeeSheet({
    super.key,
    required this.caseId,
    required this.onSave,
    this.existing,
  });

  final String caseId;
  final AttendeeModel? existing;
  final Future<void> Function(AttendeeModel) onSave;

  @override
  ConsumerState<AddAttendeeSheet> createState() => _AddAttendeeSheetState();
}

class _AddAttendeeSheetState extends ConsumerState<AddAttendeeSheet> {
  final _nameCtrl          = TextEditingController();
  final _rankCtrl          = TextEditingController();
  final _companyCtrl       = TextEditingController();
  final _representingCtrl  = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _phoneCtrl         = TextEditingController();

  AttendeeRole _role = AttendeeRole.other;
  // TODO.md §3.13 (8 July 2026): title existed on AttendeeModel already but
  // had no editor UI — always null in practice, so the report/app-UI
  // prefix fallback (Capt./Mr.-Ms.) was the only thing ever shown.
  AttendeeTitle? _title;
  bool _saving = false;
  // TODO.md §3.13 row 48 (8 July 2026): true once the surveyor has picked
  // an existing Parties contact (or dismissed the add-to-Parties prompt),
  // so a brand-new person isn't offered to be re-added on every save.
  bool _partyLinkResolved = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text         = e.fullName;
      _rankCtrl.text         = e.rankPosition     ?? '';
      _companyCtrl.text      = e.company           ?? '';
      _representingCtrl.text = e.representing      ?? '';
      _emailCtrl.text        = e.contactEmail      ?? '';
      _phoneCtrl.text        = e.contactPhone      ?? '';
      _role                  = e.roleType          ?? AttendeeRole.other;
      _title                 = e.title;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rankCtrl.dispose();
    _companyCtrl.dispose();
    _representingCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Auto-fill rank when role changes
  void _onRoleChanged(AttendeeRole role) {
    setState(() => _role = role);
    if (_rankCtrl.text.isEmpty) {
      _rankCtrl.text = switch (role) {
        AttendeeRole.master         => 'Master',
        AttendeeRole.chiefEngineer  => 'Chief Engineer',
        AttendeeRole.firstEngineer  => 'First Engineer',
        AttendeeRole.superintendent => 'Superintendent',
        AttendeeRole.classSurveyor  => 'Class Surveyor',
        AttendeeRole.serviceEngineer => 'Field Service Engineer',
        AttendeeRole.surveyor       => 'Marine Surveyor',
        _ => '',
      };
    }
  }

  // TODO.md §3.13 row 48: pick an existing Parties contact to prefill from,
  // instead of re-typing someone who's already on file.
  void _pickFromParty(AssuredContactModel c) {
    setState(() {
      _nameCtrl.text = c.fullName;
      _companyCtrl.text = c.company ?? '';
      _representingCtrl.text = c.roleTitle ?? '';
      _emailCtrl.text = c.email ?? '';
      _phoneCtrl.text = c.phone ?? '';
      _partyLinkResolved = true;
    });
  }

  Future<void> _offerAddToParties() async {
    if (!mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Parties?'),
        content: Text(
          '${_nameCtrl.text.trim()} isn\'t in this case\'s Parties/'
          'Stakeholder register yet. Add them now so they don\'t need to '
          'be re-entered later?',
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
          fullName: _nameCtrl.text.trim(),
          company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
          roleTitle: _representingCtrl.text.trim().isEmpty
              ? null : _representingCtrl.text.trim(),
          stakeholderGroup: StakeholderGroup.fromRole(_role.label),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final attendee = AttendeeModel(
        attendeeId:   widget.existing?.attendeeId ?? '',
        caseId:       widget.caseId,
        fullName:     _nameCtrl.text.trim(),
        rankPosition: _rankCtrl.text.trim().isEmpty
            ? null : _rankCtrl.text.trim(),
        company:      _companyCtrl.text.trim().isEmpty
            ? null : _companyCtrl.text.trim(),
        representing: _representingCtrl.text.trim().isEmpty
            ? null : _representingCtrl.text.trim(),
        roleType:     _role,
        title:        _title,
        contactEmail: _emailCtrl.text.trim().isEmpty
            ? null : _emailCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim().isEmpty
            ? null : _phoneCtrl.text.trim(),
      );
      await widget.onSave(attendee);
      // Only offer for a brand-new attendee who wasn't picked from Parties
      // already — not on every edit-save of an existing one.
      if (widget.existing == null && !_partyLinkResolved) {
        await _offerAddToParties();
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Edit Attendee' : 'Add Person',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // TODO.md §3.13 row 48 (8 July 2026): pick from this case's
            // existing Parties/Stakeholder contacts instead of re-typing
            // someone already on file — new attendees only.
            if (!isEdit) _PartyPickerRow(caseId: widget.caseId, onPick: _pickFromParty),

            // Role selector — first, drives rank autofill
            const Text('Role',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            DropdownButtonFormField<AttendeeRole>(
              initialValue: _role,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: AttendeeRole.values
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) _onRoleChanged(v);
              },
            ),
            const SizedBox(height: 14),

            // Title + name + rank
            Row(children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Title',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<AttendeeTitle?>(
                      initialValue: _title,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      hint: const Text('—', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<AttendeeTitle?>(
                            value: null,
                            child: Text('—', style: TextStyle(fontSize: 13))),
                        ...AttendeeTitle.values.map((t) => DropdownMenuItem(
                            value: t,
                            child:
                                Text(t.label, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _title = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: SurveyField(
                  label: 'Full Name *',
                  controller: _nameCtrl,
                  hint: 'e.g. John Samuel',
                  important: true,
                ),
              ),
            ]),
            SurveyField(
              label: 'Rank / Position',
              controller: _rankCtrl,
              hint: 'e.g. Master',
            ),

            SurveyField(
              label: 'Company',
              controller: _companyCtrl,
              hint: 'e.g. MinRes Marine Pty Ltd',
            ),

            SurveyField(
              label: 'Representing',
              controller: _representingCtrl,
              hint: 'e.g. Vessel Owners / ABL / Westrac',
            ),

            // Contact details — collapsible section
            const _ContactDivider(),

            Row(children: [
              Expanded(
                child: SurveyField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hint: 'Optional',
                  keyboard: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SurveyField(
                  label: 'Phone',
                  controller: _phoneCtrl,
                  hint: 'Optional',
                  keyboard: TextInputType.phone,
                ),
              ),
            ]),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        isEdit ? 'Update' : 'Add to Attendees',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Quick-pick chips for this case's existing Parties/Stakeholder contacts
/// (TODO.md §3.13 row 48) — empty when there are none, so it never adds
/// clutter to cases without any Parties entered yet.
class _PartyPickerRow extends ConsumerWidget {
  const _PartyPickerRow({required this.caseId, required this.onPick});
  final String caseId;
  final ValueChanged<AssuredContactModel> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(assuredContactsProvider(caseId)).value ?? [];
    if (contacts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                    c.company != null ? '${c.fullName} — ${c.company}' : c.fullName,
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

class _ContactDivider extends StatelessWidget {
  const _ContactDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('Contact details (optional)',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider()),
      ]),
    );
  }
}
