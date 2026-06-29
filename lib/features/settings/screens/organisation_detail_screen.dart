// lib/features/settings/screens/organisation_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organisation_model.dart';
import '../providers/organisations_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/save_bar.dart';

class OrganisationDetailScreen extends ConsumerStatefulWidget {
  const OrganisationDetailScreen({super.key, required this.orgId});
  final String orgId;

  @override
  ConsumerState<OrganisationDetailScreen> createState() =>
      _OrganisationDetailScreenState();
}

class _OrganisationDetailScreenState
    extends ConsumerState<OrganisationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // ── Firm details controllers ───────────────────────────────────────────────
  final _nameCtrl    = TextEditingController();
  final _abnCtrl     = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // ── Branding controllers ───────────────────────────────────────────────────
  final _primaryColourCtrl   = TextEditingController();
  final _secondaryColourCtrl = TextEditingController();

  // ── Legal text controllers ─────────────────────────────────────────────────
  final _wpHeaderCtrl      = TextEditingController();
  final _wpCoverCtrl       = TextEditingController();
  final _wpCostCtrl        = TextEditingController();
  final _wpFooterCtrl      = TextEditingController();
  final _disclaimerCtrl    = TextEditingController();
  final _waiverCtrl        = TextEditingController();

  bool _dirty = false;
  bool _saving = false;
  OrganisationModel? _org;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _nameCtrl, _abnCtrl, _addressCtrl, _phoneCtrl, _emailCtrl, _websiteCtrl,
      _primaryColourCtrl, _secondaryColourCtrl,
      _wpHeaderCtrl, _wpCoverCtrl, _wpCostCtrl, _wpFooterCtrl,
      _disclaimerCtrl, _waiverCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(OrganisationModel org) {
    if (_org?.organisationId == org.organisationId && _dirty) return;
    _org = org;
    _nameCtrl.text    = org.name;
    _abnCtrl.text     = org.abn    ?? '';
    _addressCtrl.text = org.address ?? '';
    _phoneCtrl.text   = org.phone   ?? '';
    _emailCtrl.text   = org.email   ?? '';
    _websiteCtrl.text = org.website  ?? '';
    _primaryColourCtrl.text   = org.primaryColour   ?? '';
    _secondaryColourCtrl.text = org.secondaryColour ?? '';
    _wpHeaderCtrl.text   = org.wpHeaderText      ?? _wpHeaderDefault;
    _wpCoverCtrl.text    = org.wpCoverText       ?? _wpCoverDefault;
    _wpCostCtrl.text     = org.wpCostSectionText ?? _wpCostDefault;
    _wpFooterCtrl.text   = org.wpFooterText      ?? _wpFooterDefault;
    _disclaimerCtrl.text = org.disclaimerText    ?? _disclaimerDefault;
    _waiverCtrl.text     = org.waiverText        ?? _waiverDefault;
    setState(() => _dirty = false);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_org == null) return;
    setState(() => _saving = true);
    try {
      final updated = _org!.copyWith(
        name:             _nameCtrl.text.trim(),
        abn:              _abnCtrl.text.trim().isEmpty    ? null : _abnCtrl.text.trim(),
        address:          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        phone:            _phoneCtrl.text.trim().isEmpty   ? null : _phoneCtrl.text.trim(),
        email:            _emailCtrl.text.trim().isEmpty   ? null : _emailCtrl.text.trim(),
        website:          _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        primaryColour:    _primaryColourCtrl.text.trim().isEmpty   ? null : _primaryColourCtrl.text.trim(),
        secondaryColour:  _secondaryColourCtrl.text.trim().isEmpty ? null : _secondaryColourCtrl.text.trim(),
        wpHeaderText:     _wpHeaderCtrl.text.trim().isEmpty   ? null : _wpHeaderCtrl.text.trim(),
        wpCoverText:      _wpCoverCtrl.text.trim().isEmpty    ? null : _wpCoverCtrl.text.trim(),
        wpCostSectionText: _wpCostCtrl.text.trim().isEmpty   ? null : _wpCostCtrl.text.trim(),
        wpFooterText:     _wpFooterCtrl.text.trim().isEmpty   ? null : _wpFooterCtrl.text.trim(),
        disclaimerText:   _disclaimerCtrl.text.trim().isEmpty ? null : _disclaimerCtrl.text.trim(),
        waiverText:       _waiverCtrl.text.trim().isEmpty     ? null : _waiverCtrl.text.trim(),
      );
      await ref.read(organisationsProvider.notifier).saveOrganisation(updated);
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Organisation saved'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(organisationsProvider);

    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString())),
      ),
      data: (orgs) {
        final org = orgs.where((o) => o.organisationId == widget.orgId).firstOrNull;
        if (org == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Organisation not found')),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _populate(org));

        return Scaffold(
          appBar: AppBar(
            title: Text(org.name),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Legal Text'),
                Tab(text: 'Surveyors'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _DetailsTab(
                nameCtrl: _nameCtrl,
                abnCtrl: _abnCtrl,
                addressCtrl: _addressCtrl,
                phoneCtrl: _phoneCtrl,
                emailCtrl: _emailCtrl,
                websiteCtrl: _websiteCtrl,
                primaryColourCtrl: _primaryColourCtrl,
                secondaryColourCtrl: _secondaryColourCtrl,
                onChanged: _markDirty,
              ),
              _LegalTextTab(
                wpHeaderCtrl: _wpHeaderCtrl,
                wpCoverCtrl: _wpCoverCtrl,
                wpCostCtrl: _wpCostCtrl,
                wpFooterCtrl: _wpFooterCtrl,
                disclaimerCtrl: _disclaimerCtrl,
                waiverCtrl: _waiverCtrl,
                onChanged: _markDirty,
              ),
              _SurveyorsTab(org: org),
            ],
          ),
          bottomNavigationBar: SaveBar(
            visible: _dirty,
            saving: _saving,
            onSave: _save,
          ),
        );
      },
    );
  }
}

// ── Details Tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.nameCtrl,
    required this.abnCtrl,
    required this.addressCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.websiteCtrl,
    required this.primaryColourCtrl,
    required this.secondaryColourCtrl,
    required this.onChanged,
  });

  final TextEditingController nameCtrl;
  final TextEditingController abnCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController primaryColourCtrl;
  final TextEditingController secondaryColourCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        _sectionHeader('Firm Identity'),
        _field('Firm name *', nameCtrl),
        _field('ABN', abnCtrl),
        _field('Address', addressCtrl, maxLines: 3),
        _field('Phone', phoneCtrl, keyboardType: TextInputType.phone),
        _field('Email', emailCtrl, keyboardType: TextInputType.emailAddress),
        _field('Website', websiteCtrl, keyboardType: TextInputType.url),
        const SizedBox(height: 24),
        _sectionHeader('Branding'),
        const Text(
          'Hex colour codes — e.g. #1A3A5C. Used in report cover page and running header.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _ColourField(label: 'Primary colour', ctrl: primaryColourCtrl, onChanged: onChanged),
        const SizedBox(height: 12),
        _ColourField(label: 'Secondary colour', ctrl: secondaryColourCtrl, onChanged: onChanged),
        const SizedBox(height: 8),
        const Text(
          'Logo upload will be available in a future update. '
          'Place your logo file at org-assets/<org-id>/logo.png in Supabase Storage for now.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => onChanged(),
        ),
      );
}

class _ColourField extends StatefulWidget {
  const _ColourField({
    required this.label,
    required this.ctrl,
    required this.onChanged,
  });
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  @override
  State<_ColourField> createState() => _ColourFieldState();
}

class _ColourFieldState extends State<_ColourField> {
  Color? _preview;

  @override
  void initState() {
    super.initState();
    _preview = _parse(widget.ctrl.text);
    widget.ctrl.addListener(_onCtrl);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrl);
    super.dispose();
  }

  void _onCtrl() {
    setState(() => _preview = _parse(widget.ctrl.text));
    widget.onChanged();
  }

  Color? _parse(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.ctrl,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: '#1A3A5C',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _preview ?? Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ],
    );
  }
}

// ── Legal Text Tab ────────────────────────────────────────────────────────────

class _LegalTextTab extends StatelessWidget {
  const _LegalTextTab({
    required this.wpHeaderCtrl,
    required this.wpCoverCtrl,
    required this.wpCostCtrl,
    required this.wpFooterCtrl,
    required this.disclaimerCtrl,
    required this.waiverCtrl,
    required this.onChanged,
  });

  final TextEditingController wpHeaderCtrl;
  final TextEditingController wpCoverCtrl;
  final TextEditingController wpCostCtrl;
  final TextEditingController wpFooterCtrl;
  final TextEditingController disclaimerCtrl;
  final TextEditingController waiverCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        _note('WITHOUT PREJUDICE text appears in four locations in every report. '
            'Edit each block below. Leave blank to omit that location.'),
        const SizedBox(height: 16),
        _block('Page header notice', wpHeaderCtrl),
        _block('Cover page notice', wpCoverCtrl),
        _block('Above cost table', wpCostCtrl),
        _block('Page footer', wpFooterCtrl),
        const Divider(height: 32),
        _block('End-of-report disclaimer', disclaimerCtrl),
        _block('Limitation of liability (waiver)', waiverCtrl),
      ],
    );
  }

  Widget _note(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      );

  Widget _block(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
          ),
          onChanged: (_) => onChanged(),
        ),
      );
}

// ── Surveyors Tab ─────────────────────────────────────────────────────────────

class _SurveyorsTab extends ConsumerWidget {
  const _SurveyorsTab({required this.org});
  final OrganisationModel org;

  Future<void> _addSurveyor(BuildContext context, WidgetRef ref) async {
    final nameCtrl  = TextEditingController();
    final titleCtrl = TextEditingController();
    final qualCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Surveyor Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,  decoration: const InputDecoration(labelText: 'Full name *'), autofocus: true),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title / rank', hintText: 'Master Mariner')),
              const SizedBox(height: 8),
              TextField(controller: qualCtrl,  decoration: const InputDecoration(labelText: 'Qualifications', hintText: 'FNI, MRINA')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(organisationsProvider.notifier).addSurveyorProfile(
      organisationId: org.organisationId,
      fullName:       nameCtrl.text.trim(),
      title:          titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
      qualifications: qualCtrl.text.trim().isEmpty  ? null : qualCtrl.text.trim(),
      email:          emailCtrl.text.trim().isEmpty  ? null : emailCtrl.text.trim(),
      phone:          phoneCtrl.text.trim().isEmpty  ? null : phoneCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = org.surveyorProfiles;

    return Scaffold(
      body: profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('No surveyor profiles yet',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _SurveyorCard(
                profile: profiles[i],
                onDelete: () => ref
                    .read(organisationsProvider.notifier)
                    .deleteSurveyorProfile(profiles[i].profileId),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSurveyor(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Surveyor'),
      ),
    );
  }
}

class _SurveyorCard extends StatelessWidget {
  const _SurveyorCard({required this.profile, required this.onDelete});
  final SurveyorProfileModel profile;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.navy,
          child: Icon(Icons.person, color: Colors.white, size: 20),
        ),
        title: Text(profile.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (profile.title != null) profile.title!,
            if (profile.qualifications != null) profile.qualifications!,
            if (profile.email != null) profile.email!,
          ].join(' · '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Remove surveyor?'),
              content: Text('Remove ${profile.fullName} from this organisation?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                TextButton(
                  onPressed: () { Navigator.of(ctx).pop(true); onDelete(); },
                  child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Default WP / legal text (spec §8.3 draft) ─────────────────────────────────

const _wpHeaderDefault =
    'WITHOUT PREJUDICE — This document is prepared without prejudice to the '
    'rights of all parties and is subject to review pending receipt of all '
    'relevant information.';

const _wpCoverDefault =
    'WITHOUT PREJUDICE\n\n'
    'This survey report is issued without prejudice to the rights and '
    'defences of all parties and without any admission of liability. '
    'It is prepared solely for the information of the party to whom it is '
    'addressed and must not be disclosed to any third party without prior '
    'written consent.';

const _wpCostDefault =
    'WITHOUT PREJUDICE — The cost figures presented herein are based on '
    'invoices and accounts submitted to date and are subject to audit and '
    'review. Presentation of these figures does not constitute approval '
    'of any claim or admission of liability.';

const _wpFooterDefault =
    'WITHOUT PREJUDICE — Confidential — Not for further distribution';

const _disclaimerDefault =
    'This report has been prepared solely for the use of the party to whom '
    'it is addressed. The surveyors\' findings are based on examinations '
    'carried out at the time of attendance and on information provided. '
    'No liability is accepted for any subsequent changes in condition or '
    'for reliance on this report by any third party.';

const _waiverDefault =
    'The liability of the surveying firm and its employees is limited to the '
    'fee paid for this survey. No consequential or indirect damages are '
    'accepted under any circumstances.';
