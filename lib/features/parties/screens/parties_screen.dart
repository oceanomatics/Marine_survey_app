// lib/features/parties/screens/parties_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/party_model.dart';
import '../providers/parties_provider.dart';
import '../widgets/assured_contact_sheet.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';

const _kPartiesColor = Color(0xFF2F80ED);

const _groupColors = <StakeholderGroup, Color>{
  StakeholderGroup.insured:             Color(0xFFE07B54),
  StakeholderGroup.underwriter:         Color(0xFF2E9E8F),
  StakeholderGroup.broker:              Color(0xFF2F80ED),
  StakeholderGroup.surveyor:            Color(0xFF7B61FF),
  StakeholderGroup.technicalContractor: Color(0xFFF2A33A),
  StakeholderGroup.other:               Color(0xFF8A9BB0),
};

const _groupIcons = <StakeholderGroup, IconData>{
  StakeholderGroup.insured:             Icons.directions_boat_outlined,
  StakeholderGroup.underwriter:         Icons.shield_outlined,
  StakeholderGroup.broker:              Icons.handshake_outlined,
  StakeholderGroup.surveyor:            Icons.manage_search_outlined,
  StakeholderGroup.technicalContractor: Icons.engineering_outlined,
  StakeholderGroup.other:               Icons.person_outline,
};

// ── Screen ─────────────────────────────────────────────────────────────────

class PartiesScreen extends ConsumerWidget {
  const PartiesScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partiesAsync = ref.watch(partiesProvider(caseId));
    return partiesAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data:    (parties) => _PartiesBody(caseId: caseId, initialParties: parties),
    );
  }
}

// ── Body with tabs ─────────────────────────────────────────────────────────

class _PartiesBody extends ConsumerStatefulWidget {
  const _PartiesBody({required this.caseId, required this.initialParties});
  final String caseId;
  final CasePartiesModel? initialParties;

  @override
  ConsumerState<_PartiesBody> createState() => _PartiesBodyState();
}

class _PartiesBodyState extends ConsumerState<_PartiesBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _saving = false;

  // ── Text controllers — one per field ──────────────────────────────────────
  late final TextEditingController _principalName;
  late final TextEditingController _principalCompany;
  late final TextEditingController _principalEmail;

  late final TextEditingController _reviewerName;
  late final TextEditingController _reviewerCompany;
  late final TextEditingController _reviewerEmail;

  late final TextEditingController _underwriterName;
  late final TextEditingController _underwriterCompany;
  late final TextEditingController _underwriterEmail;

  late final TextEditingController _adjusterName;
  late final TextEditingController _adjusterCompany;
  late final TextEditingController _adjusterEmail;
  late final TextEditingController _adjusterPhone;

  late final TextEditingController _assuredRepName;
  late final TextEditingController _assuredRepCompany;
  late final TextEditingController _assuredRepEmail;
  late final TextEditingController _assuredRepPhone;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));

    final p = widget.initialParties;
    _principalName    = TextEditingController(text: p?.principalName ?? '');
    _principalCompany = TextEditingController(text: p?.principalCompany ?? '');
    _principalEmail   = TextEditingController(text: p?.principalEmail ?? '');

    _reviewerName    = TextEditingController(text: p?.reviewerName ?? '');
    _reviewerCompany = TextEditingController(text: p?.reviewerCompany ?? '');
    _reviewerEmail   = TextEditingController(text: p?.reviewerEmail ?? '');

    _underwriterName    = TextEditingController(text: p?.underwriterName ?? '');
    _underwriterCompany = TextEditingController(text: p?.underwriterCompany ?? '');
    _underwriterEmail   = TextEditingController(text: p?.underwriterEmail ?? '');

    _adjusterName    = TextEditingController(text: p?.adjusterName ?? '');
    _adjusterCompany = TextEditingController(text: p?.adjusterCompany ?? '');
    _adjusterEmail   = TextEditingController(text: p?.adjusterEmail ?? '');
    _adjusterPhone   = TextEditingController(text: p?.adjusterPhone ?? '');

    _assuredRepName    = TextEditingController(text: p?.assuredRepName ?? '');
    _assuredRepCompany = TextEditingController(text: p?.assuredRepCompany ?? '');
    _assuredRepEmail   = TextEditingController(text: p?.assuredRepEmail ?? '');
    _assuredRepPhone   = TextEditingController(text: p?.assuredRepPhone ?? '');
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _principalName, _principalCompany, _principalEmail,
      _reviewerName,  _reviewerCompany,  _reviewerEmail,
      _underwriterName, _underwriterCompany, _underwriterEmail,
      _adjusterName, _adjusterCompany, _adjusterEmail, _adjusterPhone,
      _assuredRepName, _assuredRepCompany, _assuredRepEmail, _assuredRepPhone,
    ]) { c.dispose(); }
    super.dispose();
  }

  String? _v(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final model = CasePartiesModel(
        caseId:            widget.caseId,
        principalName:     _v(_principalName),
        principalCompany:  _v(_principalCompany),
        principalEmail:    _v(_principalEmail),
        reviewerName:      _v(_reviewerName),
        reviewerCompany:   _v(_reviewerCompany),
        reviewerEmail:     _v(_reviewerEmail),
        underwriterName:   _v(_underwriterName),
        underwriterCompany:_v(_underwriterCompany),
        underwriterEmail:  _v(_underwriterEmail),
        adjusterName:      _v(_adjusterName),
        adjusterCompany:   _v(_adjusterCompany),
        adjusterEmail:     _v(_adjusterEmail),
        adjusterPhone:     _v(_adjusterPhone),
        assuredRepName:    _v(_assuredRepName),
        assuredRepCompany: _v(_assuredRepCompany),
        assuredRepEmail:   _v(_assuredRepEmail),
        assuredRepPhone:   _v(_assuredRepPhone),
      );
      await ref.read(partiesProvider(widget.caseId).notifier).save(model);
      if (mounted) {
        showSavedToast(context, label: 'Parties saved');
      }
    } catch (e, st) {
      if (mounted) showError(context, 'Save failed: $e', error: e, stack: st, tag: 'App');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Stakeholder picker ────────────────────────────────────────────────────

  Future<void> _pickFor({
    required List<AssuredContactModel> contacts,
    required TextEditingController nameCtrl,
    required TextEditingController companyCtrl,
    required TextEditingController emailCtrl,
    TextEditingController? phoneCtrl,
  }) async {
    final picked = await showModalBottomSheet<AssuredContactModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StakeholderPickerSheet(contacts: contacts),
    );
    if (picked == null || !mounted) return;
    setState(() {
      nameCtrl.text    = picked.fullName;
      companyCtrl.text = picked.company ?? '';
      emailCtrl.text   = picked.email ?? '';
      phoneCtrl?.text  = picked.phone ?? '';
    });
  }

  // ── Add contact ───────────────────────────────────────────────────────────

  void _showAddContact([StakeholderGroup? initialGroup]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssuredContactSheet(
        initialGroup: initialGroup,
        onSave: (name, company, role, group, phone, email, notes) async {
          await ref.read(assuredContactsProvider(widget.caseId).notifier).add(
            caseId:           widget.caseId,
            fullName:         name,
            company:          company,
            roleTitle:        role,
            stakeholderGroup: group,
            phone:            phone,
            email:            email,
            notes:            notes,
          );
        },
      ),
    );
  }

  void _showEditContact(AssuredContactModel contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssuredContactSheet(
        initialContact: contact,
        onSave: (name, company, role, group, phone, email, notes) async {
          await ref
              .read(assuredContactsProvider(widget.caseId).notifier)
              .editContact(AssuredContactModel(
                contactId:        contact.contactId,
                caseId:           contact.caseId,
                fullName:         name,
                company:          company,
                roleTitle:        role,
                stakeholderGroup: group,
                phone:            phone,
                email:            email,
                notes:            notes,
              ));
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final contacts =
        ref.watch(assuredContactsProvider(widget.caseId)).value ?? [];
    final onPartiesTab = _tab.index == 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Parties & Stakeholders'),
        bottom: TabBar(
          controller: _tab,
          labelColor: _kPartiesColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: _kPartiesColor,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Parties'),
            Tab(icon: Icon(Icons.groups_outlined),         text: 'Stakeholders'),
          ],
        ),
      ),
      floatingActionButton: onPartiesTab
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: _kPartiesColor,
              foregroundColor: Colors.white,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showAddContact(),
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildPartiesTab(contacts),
          _buildStakeholdersTab(contacts),
        ],
      ),
    );
  }

  // ── Tab 1: Parties ────────────────────────────────────────────────────────

  Widget _buildPartiesTab(List<AssuredContactModel> contacts) {
    final hasContacts = contacts.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasContacts)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kPartiesColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPartiesColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    size: 15, color: _kPartiesColor.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Add stakeholders first (Stakeholders tab) to use the "Select" button, or fill fields manually.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ]),
            ),

          _RoleCard(
            color: _kPartiesColor,
            icon: Icons.business_outlined,
            title: 'Instructing Principal',
            subtitle: 'The firm or individual who gave us the mandate',
            nameCtrl:    _principalName,
            companyCtrl: _principalCompany,
            emailCtrl:   _principalEmail,
            hasContacts: hasContacts,
            onPick: () => _pickFor(
              contacts:   contacts,
              nameCtrl:   _principalName,
              companyCtrl:_principalCompany,
              emailCtrl:  _principalEmail,
            ),
          ),
          const SizedBox(height: 12),

          _RoleCard(
            color: AppColors.purple,
            icon: Icons.rate_review_outlined,
            title: 'Reviewer / QC',
            subtitle: 'Internal reviewer who signs off the report',
            nameCtrl:    _reviewerName,
            companyCtrl: _reviewerCompany,
            emailCtrl:   _reviewerEmail,
            hasContacts: hasContacts,
            onPick: () => _pickFor(
              contacts:   contacts,
              nameCtrl:   _reviewerName,
              companyCtrl:_reviewerCompany,
              emailCtrl:  _reviewerEmail,
            ),
          ),
          const SizedBox(height: 12),

          _RoleCard(
            color: const Color(0xFFE07B54),
            icon: Icons.directions_boat_outlined,
            title: 'Assured / Owner\'s Representative',
            subtitle: 'Owner, operator, master or their rep',
            nameCtrl:    _assuredRepName,
            companyCtrl: _assuredRepCompany,
            emailCtrl:   _assuredRepEmail,
            phoneCtrl:   _assuredRepPhone,
            hasContacts: hasContacts,
            onPick: () => _pickFor(
              contacts:   contacts,
              nameCtrl:   _assuredRepName,
              companyCtrl:_assuredRepCompany,
              emailCtrl:  _assuredRepEmail,
              phoneCtrl:  _assuredRepPhone,
            ),
          ),
          const SizedBox(height: 12),

          _RoleCard(
            color: AppColors.teal,
            icon: Icons.shield_outlined,
            title: 'Underwriter / Insurer',
            subtitle: 'e.g. QBE, Gard, Norse, Skuld',
            nameCtrl:    _underwriterName,
            companyCtrl: _underwriterCompany,
            emailCtrl:   _underwriterEmail,
            hasContacts: hasContacts,
            onPick: () => _pickFor(
              contacts:   contacts,
              nameCtrl:   _underwriterName,
              companyCtrl:_underwriterCompany,
              emailCtrl:  _underwriterEmail,
            ),
          ),
          const SizedBox(height: 12),

          _RoleCard(
            color: AppColors.amber,
            icon: Icons.gavel_outlined,
            title: 'Loss Adjuster',
            subtitle: 'Optional — complete if an adjuster is involved',
            nameCtrl:    _adjusterName,
            companyCtrl: _adjusterCompany,
            emailCtrl:   _adjusterEmail,
            phoneCtrl:   _adjusterPhone,
            hasContacts: hasContacts,
            onPick: () => _pickFor(
              contacts:   contacts,
              nameCtrl:   _adjusterName,
              companyCtrl:_adjusterCompany,
              emailCtrl:  _adjusterEmail,
              phoneCtrl:  _adjusterPhone,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Stakeholders ────────────────────────────────────────────────────

  Widget _buildStakeholdersTab(List<AssuredContactModel> contacts) {
    const groupOrder = StakeholderGroup.values;
    final grouped = <StakeholderGroup, List<AssuredContactModel>>{};
    for (final g in groupOrder) {
      final inGroup = contacts
          .where((c) => (c.stakeholderGroup ?? StakeholderGroup.other) == g)
          .toList();
      if (inGroup.isNotEmpty) grouped[g] = inGroup;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: grouped.isEmpty
          ? _StakeholdersEmpty(onAdd: () => _showAddContact())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: grouped.entries
                  .map((entry) => _StakeholderGroupSection(
                        group:    entry.key,
                        contacts: entry.value,
                        onAdd:    () => _showAddContact(entry.key),
                        onEdit:   _showEditContact,
                        onDelete: (id) => ref
                            .read(assuredContactsProvider(widget.caseId).notifier)
                            .delete(id),
                      ))
                  .toList(),
            ),
    );
  }
}

// ── Role card with "Select from stakeholders" ─────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.nameCtrl,
    required this.companyCtrl,
    required this.emailCtrl,
    this.phoneCtrl,
    required this.onPick,
    required this.hasContacts,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final TextEditingController nameCtrl;
  final TextEditingController companyCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController? phoneCtrl;
  final VoidCallback onPick;
  final bool hasContacts;

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
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
                const SizedBox(width: 8),
                // Select button
                Tooltip(
                  message: hasContacts
                      ? 'Select from stakeholders'
                      : 'Add stakeholders first',
                  child: InkWell(
                    onTap: hasContacts ? onPick : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasContacts
                            ? color.withValues(alpha: 0.08)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasContacts
                              ? color.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_search_outlined,
                            size: 13,
                            color: hasContacts
                                ? color
                                : AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('Select',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasContacts
                                    ? color
                                    : AppColors.textTertiary)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: color.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(children: [
              _tf('Name', nameCtrl, color),
              const SizedBox(height: 10),
              _tf('Company / Organisation', companyCtrl, color),
              const SizedBox(height: 10),
              _tf('Email', emailCtrl, color,
                  keyboardType: TextInputType.emailAddress),
              if (phoneCtrl != null) ...[
                const SizedBox(height: 10),
                _tf('Phone', phoneCtrl!, color,
                    keyboardType: TextInputType.phone),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tf(
    String label,
    TextEditingController ctrl,
    Color accentColor, {
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
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
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      );
}

// ── Stakeholder picker bottom sheet ────────────────────────────────────────

class _StakeholderPickerSheet extends StatefulWidget {
  const _StakeholderPickerSheet({required this.contacts});
  final List<AssuredContactModel> contacts;

  @override
  State<_StakeholderPickerSheet> createState() =>
      _StakeholderPickerSheetState();
}

class _StakeholderPickerSheetState extends State<_StakeholderPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AssuredContactModel> get _filtered {
    if (_query.isEmpty) return widget.contacts;
    final q = _query.toLowerCase();
    return widget.contacts
        .where((c) =>
            c.fullName.toLowerCase().contains(q) ||
            (c.company?.toLowerCase().contains(q) ?? false) ||
            (c.roleTitle?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select from Stakeholders',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search name, company, role…',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const Divider(height: 1),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No matches',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 62, endIndent: 16),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final color = _groupColors[
                                c.stakeholderGroup ?? StakeholderGroup.other] ??
                            AppColors.textTertiary;
                        final initials = c.fullName
                            .trim()
                            .split(RegExp(r'\s+'))
                            .take(2)
                            .map((w) =>
                                w.isNotEmpty ? w[0].toUpperCase() : '')
                            .join();
                        final subtitle = [
                          if (c.company != null) c.company!,
                          if (c.roleTitle != null) c.roleTitle!,
                        ].join(' · ');

                        return ListTile(
                          leading: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(initials,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ),
                          ),
                          title: Text(c.fullName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          subtitle: subtitle.isNotEmpty
                              ? Text(subtitle,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary))
                              : null,
                          trailing: const Icon(Icons.chevron_right,
                              size: 16, color: AppColors.textTertiary),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stakeholder group section (tab 2) ──────────────────────────────────────

class _StakeholderGroupSection extends StatelessWidget {
  const _StakeholderGroupSection({
    required this.group,
    required this.contacts,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final StakeholderGroup group;
  final List<AssuredContactModel> contacts;
  final VoidCallback onAdd;
  final void Function(AssuredContactModel) onEdit;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _groupColors[group] ?? AppColors.textTertiary;
    final icon  = _groupIcons[group] ?? Icons.person_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(group.label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.7)),
            const Spacer(),
            GestureDetector(
              onTap: onAdd,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 13, color: color),
                Text('Add',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          ...contacts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StakeholderCard(
                  contact: c,
                  color: color,
                  onEdit:   () => onEdit(c),
                  onDelete: () => onDelete(c.contactId),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Stakeholder card ───────────────────────────────────────────────────────

class _StakeholderCard extends StatelessWidget {
  const _StakeholderCard({
    required this.contact,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final AssuredContactModel contact;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = contact.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.fullName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (contact.company != null) ...[
                  const SizedBox(height: 1),
                  Text(contact.company!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
                if (contact.roleTitle != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                      border:
                          Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Text(contact.roleTitle!,
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                if (contact.phone != null || contact.email != null) ...[
                  const SizedBox(height: 5),
                  Wrap(spacing: 12, runSpacing: 3, children: [
                    if (contact.phone != null)
                      _ContactRow(
                          icon: Icons.phone_outlined, value: contact.phone!),
                    if (contact.email != null)
                      _ContactRow(
                          icon: Icons.email_outlined, value: contact.email!),
                  ]),
                ],
                if (contact.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(contact.notes!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 15, color: AppColors.textTertiary),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit',
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 15, color: AppColors.textTertiary),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove stakeholder?'),
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
                tooltip: 'Remove',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textTertiary),
          const SizedBox(width: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      );
}

// ── Stakeholders empty state ───────────────────────────────────────────────

class _StakeholdersEmpty extends StatelessWidget {
  const _StakeholdersEmpty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_add_outlined,
                size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            const Text('No stakeholders added yet.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            const Text(
              'Use "Extract with AI" on correspondence\nor tap Add to enter manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Stakeholder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: const BorderSide(color: AppColors.coral),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8))),
              ),
            ),
          ],
        ),
      );
}
