// lib/features/parties/screens/parties_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/party_model.dart';
import '../providers/parties_provider.dart';
import '../widgets/assured_contact_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';

// Accent colour for Parties module
const _kPartiesColor = Color(0xFF2F80ED);

class PartiesScreen extends ConsumerWidget {
  const PartiesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partiesAsync = ref.watch(partiesProvider(caseId));
    final contactsAsync = ref.watch(assuredContactsProvider(caseId));

    return partiesAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (parties) => _PartiesForm(
        caseId: caseId,
        parties: parties,
        contacts: contactsAsync.value ?? [],
      ),
    );
  }
}

// ── Form ──────────────────────────────────────────────────────────────────

class _PartiesForm extends ConsumerStatefulWidget {
  const _PartiesForm({
    required this.caseId,
    required this.parties,
    required this.contacts,
  });

  final String caseId;
  final CasePartiesModel? parties;
  final List<AssuredContactModel> contacts;

  @override
  ConsumerState<_PartiesForm> createState() => _PartiesFormState();
}

class _PartiesFormState extends ConsumerState<_PartiesForm> {
  // Principal
  late final TextEditingController _principalName;
  late final TextEditingController _principalCompany;
  late final TextEditingController _principalEmail;

  // Reviewer
  late final TextEditingController _reviewerName;
  late final TextEditingController _reviewerCompany;
  late final TextEditingController _reviewerEmail;

  // Underwriter
  late final TextEditingController _underwriterName;
  late final TextEditingController _underwriterCompany;
  late final TextEditingController _underwriterEmail;

  // Adjuster
  late final TextEditingController _adjusterName;
  late final TextEditingController _adjusterCompany;
  late final TextEditingController _adjusterEmail;
  late final TextEditingController _adjusterPhone;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parties;
    _principalName    = TextEditingController(text: p?.principalName ?? '');
    _principalCompany = TextEditingController(text: p?.principalCompany ?? '');
    _principalEmail   = TextEditingController(text: p?.principalEmail ?? '');
    _reviewerName     = TextEditingController(text: p?.reviewerName ?? '');
    _reviewerCompany  = TextEditingController(text: p?.reviewerCompany ?? '');
    _reviewerEmail    = TextEditingController(text: p?.reviewerEmail ?? '');
    _underwriterName    = TextEditingController(text: p?.underwriterName ?? '');
    _underwriterCompany = TextEditingController(text: p?.underwriterCompany ?? '');
    _underwriterEmail   = TextEditingController(text: p?.underwriterEmail ?? '');
    _adjusterName    = TextEditingController(text: p?.adjusterName ?? '');
    _adjusterCompany = TextEditingController(text: p?.adjusterCompany ?? '');
    _adjusterEmail   = TextEditingController(text: p?.adjusterEmail ?? '');
    _adjusterPhone   = TextEditingController(text: p?.adjusterPhone ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _principalName, _principalCompany, _principalEmail,
      _reviewerName,  _reviewerCompany,  _reviewerEmail,
      _underwriterName, _underwriterCompany, _underwriterEmail,
      _adjusterName, _adjusterCompany, _adjusterEmail, _adjusterPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _val(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final model = CasePartiesModel(
        caseId:             widget.caseId,
        principalName:      _val(_principalName),
        principalCompany:   _val(_principalCompany),
        principalEmail:     _val(_principalEmail),
        reviewerName:       _val(_reviewerName),
        reviewerCompany:    _val(_reviewerCompany),
        reviewerEmail:      _val(_reviewerEmail),
        underwriterName:    _val(_underwriterName),
        underwriterCompany: _val(_underwriterCompany),
        underwriterEmail:   _val(_underwriterEmail),
        adjusterName:       _val(_adjusterName),
        adjusterCompany:    _val(_adjusterCompany),
        adjusterEmail:      _val(_adjusterEmail),
        adjusterPhone:      _val(_adjusterPhone),
      );
      await ref.read(partiesProvider(widget.caseId).notifier).save(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parties saved'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAddContact() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssuredContactSheet(
        onSave: (name, role, phone, email, notes) async {
          await ref.read(assuredContactsProvider(widget.caseId).notifier).add(
                caseId:    widget.caseId,
                fullName:  name,
                roleTitle: role,
                phone:     phone,
                email:     email,
                notes:     notes,
              );
        },
      ),
    );
  }

  Future<void> _deleteContact(String contactId) async {
    await ref
        .read(assuredContactsProvider(widget.caseId).notifier)
        .delete(contactId);
  }

  @override
  Widget build(BuildContext context) {
    final contacts =
        ref.watch(assuredContactsProvider(widget.caseId)).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Parties & Client')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: _kPartiesColor,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PartySection(
              color: _kPartiesColor,
              icon: Icons.business_outlined,
              title: 'Instructing Principal',
              subtitle: 'The firm or individual who gave us the mandate',
              fields: [
                _FieldSpec('Name',    _principalName),
                _FieldSpec('Company', _principalCompany),
                _FieldSpec('Email',   _principalEmail,
                    keyboardType: TextInputType.emailAddress),
              ],
            ),
            const SizedBox(height: 12),
            _PartySection(
              color: AppColors.purple,
              icon: Icons.rate_review_outlined,
              title: 'Reviewer / QC',
              subtitle: 'Internal reviewer who signs off the report',
              fields: [
                _FieldSpec('Name',    _reviewerName),
                _FieldSpec('Company', _reviewerCompany),
                _FieldSpec('Email',   _reviewerEmail,
                    keyboardType: TextInputType.emailAddress),
              ],
            ),
            const SizedBox(height: 12),
            _PartySection(
              color: AppColors.teal,
              icon: Icons.shield_outlined,
              title: 'Underwriter / Insurer',
              subtitle: 'e.g. QBE, Gard, Norse, Skuld',
              fields: [
                _FieldSpec('Name',    _underwriterName),
                _FieldSpec('Company', _underwriterCompany),
                _FieldSpec('Email',   _underwriterEmail,
                    keyboardType: TextInputType.emailAddress),
              ],
            ),
            const SizedBox(height: 12),
            _PartySection(
              color: AppColors.amber,
              icon: Icons.gavel_outlined,
              title: 'Loss Adjuster',
              subtitle: 'Optional — complete if an adjuster is involved',
              fields: [
                _FieldSpec('Name',    _adjusterName),
                _FieldSpec('Company', _adjusterCompany),
                _FieldSpec('Email',   _adjusterEmail,
                    keyboardType: TextInputType.emailAddress),
                _FieldSpec('Phone',   _adjusterPhone,
                    keyboardType: TextInputType.phone),
              ],
            ),
            const SizedBox(height: 16),
            // ── Assured contacts ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.coral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.people_outline,
                              color: AppColors.coral, size: 17),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assured Contacts',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                              Text(
                                'Master, owner rep, operator — as many as needed',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddContact,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.coral),
                        ),
                      ],
                    ),
                  ),
                  if (contacts.isNotEmpty)
                    const Divider(height: 1, color: AppColors.border),
                  ...contacts.map((c) => _AssuredContactTile(
                        contact: c,
                        onDelete: () => _deleteContact(c.contactId),
                      )),
                  if (contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        'No assured contacts added yet.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Party section card ─────────────────────────────────────────────────────

class _FieldSpec {
  const _FieldSpec(this.label, this.controller,
      {this.keyboardType = TextInputType.text});
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
}

class _PartySection extends StatelessWidget {
  const _PartySection({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_FieldSpec> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: color.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: fields
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: f.controller,
                          keyboardType: f.keyboardType,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: f.label,
                            labelStyle: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assured contact tile ───────────────────────────────────────────────────

class _AssuredContactTile extends StatelessWidget {
  const _AssuredContactTile({
    required this.contact,
    required this.onDelete,
  });

  final AssuredContactModel contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: AppColors.coral, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.fullName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (contact.roleTitle != null) ...[
                  const SizedBox(height: 1),
                  Text(contact.roleTitle!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
                if (contact.phone != null || contact.email != null) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (contact.phone != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.phone_outlined,
                              size: 11, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(contact.phone!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary)),
                        ]),
                      if (contact.email != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.email_outlined,
                              size: 11, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(contact.email!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary)),
                        ]),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.textTertiary, size: 18),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove contact?'),
                  content: Text('Remove ${contact.fullName}?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true) onDelete();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
