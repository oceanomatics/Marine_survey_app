// lib/features/settings/screens/organisation_detail_screen.dart

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organisation_model.dart';
import '../providers/organisations_provider.dart';
import '../../../core/api/supabase_client.dart';
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
                org: org,
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
    required this.org,
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

  final OrganisationModel org;
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
        const SizedBox(height: 24),
        _sectionHeader('Logos'),
        const Text(
          'The first logo is the primary letterhead logo, embedded in the '
          'report running header. Add a second for co-branding.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _LogoManager(org: org),
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

  Future<void> _pickSwatch() async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => _SwatchPickerDialog(
        title: widget.label,
        current: _preview,
      ),
    );
    if (picked != null) {
      widget.ctrl.text = '#${colourToHex6(picked)}';
    }
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
        Tooltip(
          message: 'Pick from swatches',
          child: InkWell(
            onTap: _pickSwatch,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _preview ?? Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.palette_outlined,
                size: 18,
                color: _preview == null
                    ? AppColors.textSecondary
                    : (_preview!.computeLuminance() > 0.5
                        ? Colors.black54
                        : Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Swatch picker dialog ──────────────────────────────────────────────────────
// A dependency-free colour picker: a grid of curated preset swatches. Manual
// hex entry remains available in the field for fully custom colours.

class _SwatchPickerDialog extends StatelessWidget {
  const _SwatchPickerDialog({required this.title, required this.current});
  final String title;
  final Color? current;

  // Curated palette — corporate/marine tones plus neutrals and accents.
  static const List<int> _swatches = [
    0xFF1A3A5C, 0xFF13293D, 0xFF006494, 0xFF247BA0, 0xFF1B98E0,
    0xFF0B7A75, 0xFF00A896, 0xFF2A9D8F, 0xFF264653, 0xFF3D5A80,
    0xFF6A4C93, 0xFF8E44AD, 0xFFC0392B, 0xFFD62828, 0xFFE76F51,
    0xFFEE964B, 0xFFF4A261, 0xFFE9C46A, 0xFF457B9D, 0xFF1D3557,
    0xFF212529, 0xFF495057, 0xFF6C757D, 0xFFADB5BD, 0xFFFFFFFF,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _swatches.map((v) {
            final c = Color(v);
            final selected = current != null &&
                colourToHex6(current!) == colourToHex6(c);
            return InkWell(
              onTap: () => Navigator.of(context).pop(c),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.navy : AppColors.border,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check,
                        size: 18,
                        color: c.computeLuminance() > 0.5
                            ? Colors.black54
                            : Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Uppercase 6-digit RRGGBB hex (no leading '#') for a [Color], using the
/// non-deprecated component accessors (0.0–1.0 doubles).
String colourToHex6(Color c) {
  String h(double x) => (x * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '${h(c.r)}${h(c.g)}${h(c.b)}'.toUpperCase();
}

// ── Logo Manager ──────────────────────────────────────────────────────────────
// Picks an image file, uploads it to the `organisation_assets` Supabase Storage
// bucket, and appends its path to the organisation's ordered logo list. The
// first logo is the primary letterhead logo embedded in the report header.

class _LogoManager extends ConsumerStatefulWidget {
  const _LogoManager({required this.org});
  final OrganisationModel org;

  @override
  ConsumerState<_LogoManager> createState() => _LogoManagerState();
}

class _LogoManagerState extends ConsumerState<_LogoManager> {
  static const _bucket = 'organisation_assets';
  bool _busy = false;

  List<String> get _paths => widget.org.logoStoragePaths;

  Future<void> _addLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Could not read the selected file.');
      return;
    }
    final ext = (file.extension ?? 'png').toLowerCase();
    final path =
        '${widget.org.organisationId}/logo_${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _busy = true);
    try {
      await SupabaseService.uploadFile(
        bucket: _bucket,
        path: path,
        bytes: bytes,
        mimeType: _mimeFor(ext),
      );
      final updated =
          widget.org.copyWith(logoStoragePaths: [..._paths, path]);
      await ref.read(organisationsProvider.notifier).saveOrganisation(updated);
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLogo(String path) async {
    setState(() => _busy = true);
    try {
      // Remove from the list first (source of truth for the report). Deleting
      // the storage object is best-effort — orphaned bytes are harmless.
      final remaining = _paths.where((p) => p != path).toList();
      final updated = widget.org.copyWith(logoStoragePaths: remaining);
      await ref.read(organisationsProvider.notifier).saveOrganisation(updated);
      try {
        await SupabaseService.client.storage.from(_bucket).remove([path]);
      } catch (_) {/* best-effort */}
    } catch (e) {
      _snack('Remove failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'image/png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_paths.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(children: [
              Icon(Icons.image_outlined, size: 20, color: AppColors.textTertiary),
              SizedBox(width: 10),
              Expanded(
                child: Text('No logos uploaded yet.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ]),
          )
        else
          ...List.generate(_paths.length, (i) => _LogoTile(
                bucket: _bucket,
                path: _paths[i],
                isPrimary: i == 0,
                onRemove: _busy ? null : () => _removeLogo(_paths[i]),
              )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addLogo,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined, size: 18),
          label: Text(_paths.isEmpty ? 'Upload logo' : 'Add another logo'),
        ),
      ],
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.bucket,
    required this.path,
    required this.isPrimary,
    required this.onRemove,
  });
  final String bucket;
  final String path;
  final bool isPrimary;
  final VoidCallback? onRemove;

  Future<Uint8List?> _download() async {
    try {
      return await SupabaseService.client.storage.from(bucket).download(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List?>(
            future: _download(),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final data = snap.data;
              if (data == null) {
                return const Icon(Icons.broken_image_outlined,
                    size: 20, color: AppColors.textTertiary);
              }
              return Image.memory(data, fit: BoxFit.contain);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPrimary ? 'Primary (letterhead)' : 'Secondary',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                path.split('/').last,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: onRemove,
          tooltip: 'Remove logo',
        ),
      ]),
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
