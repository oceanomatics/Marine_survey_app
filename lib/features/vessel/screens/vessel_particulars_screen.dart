// lib/features/vessel/screens/vessel_particulars_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/vessel_provider.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../settings/providers/account_provider.dart';
import '../../../core/api/equasis_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../widgets/machinery_card.dart';
import '../widgets/add_machinery_sheet.dart';
import '../widgets/section_header.dart';
import '../widgets/survey_field.dart';
import '../../../shared/widgets/save_bar.dart';
import 'dart:io';
import '../../photos/providers/photo_provider.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';

// ── ABL London H&M Report template option lists ───────────────────────────────

const _vesselTypes = [
  'general cargo ship', 'oil tanker', 'products carrier', 'ro ro',
  'passenger ferry', 'offshore support vessel', 'offshore supply vessel',
  'container ship', 'anchor handling tug', 'tug', 'bulk carrier',
  'chemical tanker', 'container carrier', 'Reefer vessel', 'LNG carrier',
  'LPG carrier', 'Oceanographic Research Vessel', 'Seismic Survey Vessel',
  'dive support vessel', 'tender', 'crew boat', 'cable layer',
  'pipe layer', 'work boat', 'pilot boat',
];

const _classSocieties = [
  'American Bureau of Shipping', 'Bureau Veritas', 'DNV GL',
  'Lloyds Register of Shipping', 'Nippon Kaiji Kyokai', 'R.I.N.A.',
  'China Classification Society', 'Russian Maritime Register of Shipping',
  'Korean Register of Shipping', 'Polish Register of Shipping',
  'Indian Register of Shipping', 'Croatian Register of Shipping',
  'A.B.S.', 'B.V.', 'C.C.S.', 'C.R.S', 'I.R.S', 'K.R.S.',
  'L.R.S.', 'N.K.K.', 'R.M.R.S', 'P.R.S',
];

const _propulsionTypes = [
  'single screw, motor driven',
  'twin screw, motor driven',
  'single screw, steam turbine driven',
];

const _propellerTypes = [
  'Single screw fixed pitch', 'Twin screw fixed pitch',
  'Single Azipod', 'Twin Azipods',
  'Single screw variable pitch', 'Twin screw variable pitch',
  'Water Jet',
];

const _propulsionDriveTypes = [
  'Direct drive',
  'Via reduction gearbox',
  'Via double reduction gearbox',
  'Electric Motor',
];

const _breadthQualifiers = [
  'Moulded Breadth', 'Extreme Breadth', 'Beam (OA)', 'Breadth', 'Beam',
];

const _draftQualifiers = ['Load Line Draft', 'Max Draft', 'Draft'];

const _tankerTypes = {
  'oil tanker', 'products carrier', 'chemical tanker',
  'LNG carrier', 'LPG carrier', 'Reefer vessel',
};

const _cargoTypes = {
  'general cargo ship', 'bulk carrier', 'container ship', 'container carrier',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class VesselParticularsScreen extends ConsumerStatefulWidget {
  const VesselParticularsScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<VesselParticularsScreen> createState() =>
      _VesselParticularsScreenState();
}

class _VesselParticularsScreenState
    extends ConsumerState<VesselParticularsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saving = false;
  bool _hasChanges = false;
  bool _fetchingEquasis = false;

  // Text controllers
  final _nameCtrl         = TextEditingController();
  final _imoCtrl          = TextEditingController();
  final _callSignCtrl     = TextEditingController();
  final _mmsiCtrl         = TextEditingController();
  final _flagCtrl         = TextEditingController();
  final _portCtrl         = TextEditingController();
  final _gtCtrl           = TextEditingController();
  final _ntCtrl           = TextEditingController();
  final _dwtCtrl          = TextEditingController();
  final _loaCtrl          = TextEditingController();
  final _lbpCtrl          = TextEditingController();
  final _breadthCtrl      = TextEditingController();
  final _depthCtrl        = TextEditingController();
  final _draftCtrl        = TextEditingController();
  final _yearBuiltCtrl    = TextEditingController();
  final _buildYardCtrl    = TextEditingController();
  final _buildCountryCtrl = TextEditingController();
  final _ownersCtrl       = TextEditingController();
  final _operatorsCtrl    = TextEditingController();
  final _notationCtrl     = TextEditingController();
  final _speedCtrl        = TextEditingController();
  final _holdsCtrl        = TextEditingController();
  final _tanksCtrl        = TextEditingController();
  final _mcrValueCtrl     = TextEditingController();
  final _mcrRpmCtrl       = TextEditingController();

  // Dropdown / chip selections
  String? _vesselType;
  String? _classSociety;
  String? _breadthQualifier;
  String? _draftQualifier;
  String? _propulsionType;
  String? _propellerType;
  String? _propulsionDriveType;
  String _mcrPowerUnit = 'kW';

  String? _vesselId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _nameCtrl, _imoCtrl, _callSignCtrl, _mmsiCtrl, _flagCtrl, _portCtrl,
      _gtCtrl, _ntCtrl, _dwtCtrl, _loaCtrl, _lbpCtrl,
      _breadthCtrl, _depthCtrl, _draftCtrl, _yearBuiltCtrl,
      _buildYardCtrl, _buildCountryCtrl, _ownersCtrl, _operatorsCtrl,
      _notationCtrl, _speedCtrl, _holdsCtrl, _tanksCtrl,
      _mcrValueCtrl, _mcrRpmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFields(VesselModel v) {
    _vesselId           = v.vesselId;
    _nameCtrl.text      = v.name;
    _imoCtrl.text       = v.imoNumber          ?? '';
    _callSignCtrl.text  = v.callSign           ?? '';
    _mmsiCtrl.text      = v.mmsi               ?? '';
    _vesselType         = v.vesselType;
    _flagCtrl.text      = v.flag               ?? '';
    _portCtrl.text      = v.portOfRegistry     ?? '';
    _gtCtrl.text        = v.grossTonnage?.toString()    ?? '';
    _ntCtrl.text        = v.netTonnage?.toString()      ?? '';
    _dwtCtrl.text       = v.deadweight?.toString()      ?? '';
    _holdsCtrl.text     = v.holdsCount?.toString()      ?? '';
    _tanksCtrl.text     = v.tanksCount?.toString()      ?? '';
    _loaCtrl.text       = v.lengthOa?.toString()        ?? '';
    _lbpCtrl.text       = v.lengthBp?.toString()        ?? '';
    _breadthCtrl.text   = v.breadth?.toString()         ?? '';
    _breadthQualifier   = v.breadthQualifier;
    _depthCtrl.text     = v.depth?.toString()           ?? '';
    _draftCtrl.text     = v.maxDraft?.toString()        ?? '';
    _draftQualifier     = v.draftQualifier;
    _yearBuiltCtrl.text     = v.yearBuilt?.toString()   ?? '';
    _buildYardCtrl.text     = v.buildYard               ?? '';
    _buildCountryCtrl.text  = v.buildCountry            ?? '';
    _ownersCtrl.text        = v.owners                  ?? '';
    _operatorsCtrl.text     = v.operators               ?? '';
    _classSociety           = v.classSociety;
    _notationCtrl.text      = v.classNotation           ?? '';
    _speedCtrl.text         = v.serviceSpeed?.toString()  ?? '';
    _propulsionType         = v.propulsionType;
    _propellerType          = v.propellerType;
    _propulsionDriveType    = v.propulsionDriveType;
    _mcrValueCtrl.text      = v.mcrPowerValue?.toString() ?? '';
    _mcrRpmCtrl.text        = v.mcrRpm?.toString()        ?? '';
    _mcrPowerUnit           = v.mcrPowerUnit ?? 'kW';
  }

  Map<String, dynamic> _collectFields() => {
    'name':                 _nameCtrl.text.trim(),
    'imo_number':           _imoCtrl.text.trim().isEmpty      ? null : _imoCtrl.text.trim(),
    'call_sign':            _callSignCtrl.text.trim().isEmpty ? null : _callSignCtrl.text.trim(),
    'mmsi':                 _mmsiCtrl.text.trim().isEmpty     ? null : _mmsiCtrl.text.trim(),
    'vessel_type':          _vesselType,
    'flag':                 _flagCtrl.text.trim().isEmpty     ? null : _flagCtrl.text.trim(),
    'port_of_registry':     _portCtrl.text.trim().isEmpty     ? null : _portCtrl.text.trim(),
    'gross_tonnage':        double.tryParse(_gtCtrl.text.trim()),
    'net_tonnage':          double.tryParse(_ntCtrl.text.trim()),
    'deadweight':           double.tryParse(_dwtCtrl.text.trim()),
    'holds_count':          int.tryParse(_holdsCtrl.text.trim()),
    'tanks_count':          int.tryParse(_tanksCtrl.text.trim()),
    'length_oa':            double.tryParse(_loaCtrl.text.trim()),
    'length_bp':            double.tryParse(_lbpCtrl.text.trim()),
    'breadth':              double.tryParse(_breadthCtrl.text.trim()),
    'breadth_qualifier':    _breadthQualifier,
    'depth':                double.tryParse(_depthCtrl.text.trim()),
    'max_draft':            double.tryParse(_draftCtrl.text.trim()),
    'draft_qualifier':      _draftQualifier,
    'year_built':           int.tryParse(_yearBuiltCtrl.text.trim()),
    'build_yard':           _buildYardCtrl.text.trim().isEmpty     ? null : _buildYardCtrl.text.trim(),
    'build_country':        _buildCountryCtrl.text.trim().isEmpty  ? null : _buildCountryCtrl.text.trim(),
    'owners':               _ownersCtrl.text.trim().isEmpty        ? null : _ownersCtrl.text.trim(),
    'operators':            _operatorsCtrl.text.trim().isEmpty     ? null : _operatorsCtrl.text.trim(),
    'class_society':        _classSociety,
    'class_notation':       _notationCtrl.text.trim().isEmpty      ? null : _notationCtrl.text.trim(),
    'service_speed':        double.tryParse(_speedCtrl.text.trim()),
    'propulsion_type':      _propulsionType,
    'propeller_type':       _propellerType,
    'propulsion_drive_type': _propulsionDriveType,
    'mcr_power_value':      double.tryParse(_mcrValueCtrl.text.trim()),
    'mcr_rpm':              int.tryParse(_mcrRpmCtrl.text.trim()),
    'mcr_power_unit':       _mcrPowerUnit,
  };

  Future<void> _save(String vesselId) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .saveVessel(vesselId: vesselId, fields: _collectFields());
      setState(() => _hasChanges = false);
      ref.invalidate(caseProvider(widget.caseId));
      ref.invalidate(casesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vessel particulars saved'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on ImoConflictException catch (e) {
      if (mounted) showError(context, e.toString(), tag: 'Vessel');
    } catch (e, st) {
      if (mounted) showError(context, 'Save failed: $e', error: e, stack: st, tag: 'Vessel');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createAndSave() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vessel name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final vessel = await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .createVessel(caseId: widget.caseId, name: _nameCtrl.text.trim());
      await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .saveVessel(vesselId: vessel.vesselId, fields: _collectFields());
      setState(() {
        _vesselId = vessel.vesselId;
        _hasChanges = false;
      });
      ref.invalidate(caseProvider(widget.caseId));
      ref.invalidate(casesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vessel particulars saved'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on ImoConflictException catch (e) {
      if (mounted) showError(context, e.toString(), tag: 'Vessel');
    } catch (e, st) {
      if (mounted) showError(context, 'Save failed: $e', error: e, stack: st, tag: 'Vessel');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fetchFromEquasis() async {
    if (_fetchingEquasis) return;
    _fetchingEquasis = true;

    final imo = _imoCtrl.text.trim();
    if (imo.isEmpty) {
      _fetchingEquasis = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Enter an IMO number first')));
      }
      return;
    }

    final accountAsync = ref.read(accountProvider);
    if (accountAsync.isLoading) {
      _fetchingEquasis = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Account still loading — please try again')));
      }
      return;
    }
    final equasisAcc = accountAsync.value?.equasisAccount;
    if (equasisAcc == null) {
      _fetchingEquasis = false;
      if (!mounted) return;
      final router = GoRouter.of(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Text('No Equasis account configured'),
          action: SnackBarAction(label: 'Set up', onPressed: () => router.go('/account')),
          duration: const Duration(seconds: 5),
        ));
      return;
    }

    setState(() {});
    try {
      final pdfBytes = await EquasisService.fetchVesselReport(
        imo: imo,
        username: equasisAcc.username,
        password: equasisAcc.password,
        vesselName: _nameCtrl.text.trim(),
      );

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final filename = 'equasis_${imo}_$dateStr.pdf';

      await ref.read(documentProvider(widget.caseId).notifier).uploadAndCreate(
            caseId: widget.caseId,
            bytes: pdfBytes,
            filename: filename,
            mimeType: 'application/pdf',
            title: 'Equasis Ship Folder — IMO $imo ($dateStr)',
            category: DocCategory.intelligenceReport,
            willExtract: true,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equasis report saved to Document Vault ✓'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) showError(context, 'Equasis fetch failed: $e', error: e, stack: st, tag: 'Vessel');
    } finally {
      if (mounted) setState(() => _fetchingEquasis = false);
    }
  }

  void _markChanged() => setState(() => _hasChanges = true);

  @override
  Widget build(BuildContext context) {
    final vesselAsync = ref.watch(vesselForCaseProvider(widget.caseId));

    return vesselAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Vessel Particulars')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load vessel data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(vesselForCaseProvider(widget.caseId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (vessel) {
        if (vessel != null && _vesselId != vessel.vesselId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _populateFields(vessel);
            setState(() => _vesselId = vessel.vesselId);
          });
        }
        return _buildScaffold(vessel);
      },
    );
  }

  Widget _buildScaffold(VesselModel? vessel) {
    final vesselId = vessel?.vesselId ?? _vesselId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vessel Particulars'),
            if (vessel != null)
              Text(
                vessel.name,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Identity'),
            Tab(text: 'Dimensions'),
            Tab(text: 'Machinery'),
          ],
        ),
      ),
      bottomNavigationBar: SaveBar(
        visible: _hasChanges || vesselId == null,
        saving: _saving,
        onSave: () => vesselId != null ? _save(vesselId) : _createAndSave(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _IdentityTab(
            caseId:           widget.caseId,
            nameCtrl:         _nameCtrl,
            imoCtrl:          _imoCtrl,
            callSignCtrl:     _callSignCtrl,
            mmsiCtrl:         _mmsiCtrl,
            vesselType:       _vesselType,
            flagCtrl:         _flagCtrl,
            portCtrl:         _portCtrl,
            ownersCtrl:       _ownersCtrl,
            operatorsCtrl:    _operatorsCtrl,
            classSociety:     _classSociety,
            notationCtrl:     _notationCtrl,
            yearBuiltCtrl:    _yearBuiltCtrl,
            buildYardCtrl:    _buildYardCtrl,
            buildCountryCtrl: _buildCountryCtrl,
            onChanged:              _markChanged,
            onVesselTypeChanged:    (v) { setState(() { _vesselType = v; _hasChanges = true; }); },
            onClassSocietyChanged:  (v) { setState(() { _classSociety = v; _hasChanges = true; }); },
            onEquasisFetch:   _fetchFromEquasis,
            fetchingEquasis:  _fetchingEquasis,
          ),
          _DimensionsTab(
            gtCtrl:      _gtCtrl,
            ntCtrl:      _ntCtrl,
            dwtCtrl:     _dwtCtrl,
            holdsCtrl:   _holdsCtrl,
            tanksCtrl:   _tanksCtrl,
            vesselType:  _vesselType,
            loaCtrl:     _loaCtrl,
            lbpCtrl:     _lbpCtrl,
            breadthCtrl: _breadthCtrl,
            depthCtrl:   _depthCtrl,
            draftCtrl:   _draftCtrl,
            speedCtrl:   _speedCtrl,
            breadthQualifier: _breadthQualifier,
            draftQualifier:   _draftQualifier,
            onChanged:                  _markChanged,
            onBreadthQualifierChanged:  (v) { setState(() { _breadthQualifier = v; _hasChanges = true; }); },
            onDraftQualifierChanged:    (v) { setState(() { _draftQualifier = v; _hasChanges = true; }); },
          ),
          vessel?.vesselId != null
              ? _MachineryTab(
                  vesselId:            vessel!.vesselId,
                  caseId:              widget.caseId,
                  propulsionType:      _propulsionType,
                  propellerType:       _propellerType,
                  propulsionDriveType: _propulsionDriveType,
                  mcrPowerUnit:        _mcrPowerUnit,
                  mcrValueCtrl:        _mcrValueCtrl,
                  mcrRpmCtrl:          _mcrRpmCtrl,
                  onPropulsionTypeChanged:    (v) { setState(() { _propulsionType = v; _hasChanges = true; }); },
                  onPropellerTypeChanged:     (v) { setState(() { _propellerType = v; _hasChanges = true; }); },
                  onDriveTypeChanged:         (v) { setState(() { _propulsionDriveType = v; _hasChanges = true; }); },
                  onMcrUnitChanged:           (v) { setState(() { _mcrPowerUnit = v; _hasChanges = true; }); },
                  onChanged:                  _markChanged,
                )
              : const _MachineryPlaceholder(),
        ],
      ),
    );
  }
}

// ── Tab 1: Identity ───────────────────────────────────────────────────────────

class _IdentityTab extends ConsumerStatefulWidget {
  const _IdentityTab({
    required this.caseId,
    required this.nameCtrl,
    required this.imoCtrl,
    required this.callSignCtrl,
    required this.mmsiCtrl,
    required this.vesselType,
    required this.flagCtrl,
    required this.portCtrl,
    required this.ownersCtrl,
    required this.operatorsCtrl,
    required this.classSociety,
    required this.notationCtrl,
    required this.yearBuiltCtrl,
    required this.buildYardCtrl,
    required this.buildCountryCtrl,
    required this.onChanged,
    required this.onVesselTypeChanged,
    required this.onClassSocietyChanged,
    this.onEquasisFetch,
    this.fetchingEquasis = false,
  });

  final String caseId;
  final TextEditingController nameCtrl, imoCtrl, callSignCtrl, mmsiCtrl;
  final String? vesselType;
  final TextEditingController flagCtrl, portCtrl;
  final TextEditingController ownersCtrl, operatorsCtrl;
  final String? classSociety;
  final TextEditingController notationCtrl;
  final TextEditingController yearBuiltCtrl, buildYardCtrl, buildCountryCtrl;
  final VoidCallback onChanged;
  final ValueChanged<String?> onVesselTypeChanged;
  final ValueChanged<String?> onClassSocietyChanged;
  final VoidCallback? onEquasisFetch;
  final bool fetchingEquasis;

  @override
  ConsumerState<_IdentityTab> createState() => _IdentityTabState();
}

class _IdentityTabState extends ConsumerState<_IdentityTab> {
  Future<void> _pickVesselPhoto() async {
    final picked = await showModalBottomSheet<List<dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CasePhotoPickerSheet(
        caseId: widget.caseId,
        title: 'Select Vessel General View',
        accentColor: AppColors.teal,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final photo = picked.first;
    await ref
        .read(photosProvider(widget.caseId).notifier)
        .attachLink(photo.id as String, 'vessel_general_view', widget.caseId);
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosProvider(widget.caseId)).value ?? [];
    final vesselPhotoMatches = photos.where(
        (p) => p.linkedToType == 'vessel_general_view' && p.linkedToId == widget.caseId);
    final vesselPhoto =
        vesselPhotoMatches.isEmpty ? null : vesselPhotoMatches.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Vessel general view photo ──────────────────────────────
        if (vesselPhoto != null)
          GestureDetector(
            onTap: _pickVesselPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(vesselPhoto.thumbnailPath ?? vesselPhoto.localPath),
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: AppColors.surface,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: _pickVesselPhoto,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 20, color: AppColors.textTertiary),
                  SizedBox(width: 8),
                  Text('Add vessel general view',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        const VesselSectionHeader(
          title: 'Vessel Identity',
          icon: Icons.directions_boat_outlined,
          color: AppColors.teal,
        ),
        const SizedBox(height: 12),

        SurveyField(
          label: 'Vessel Name *',
          controller: widget.nameCtrl,
          hint: 'e.g. MINRES ODIN',
          onChanged: (_) => widget.onChanged(),
          capitalization: TextCapitalization.characters,
        ),

        // IMO + Equasis button
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SurveyField(
                label: 'IMO Number',
                controller: widget.imoCtrl,
                hint: 'e.g. 9374935',
                keyboard: TextInputType.number,
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: widget.fetchingEquasis
                  ? const SizedBox(
                      width: 36, height: 36,
                      child: Center(child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.teal),
                      )))
                  : Tooltip(
                      message: 'Fetch from Equasis',
                      child: InkWell(
                        onTap: widget.onEquasisFetch,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: widget.onEquasisFetch != null
                                ? AppColors.lightTeal
                                : AppColors.surface,
                            border: Border.all(
                              color: widget.onEquasisFetch != null
                                  ? AppColors.teal
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.travel_explore, size: 15,
                                color: widget.onEquasisFetch != null
                                    ? AppColors.teal
                                    : AppColors.textTertiary),
                            const SizedBox(width: 5),
                            Text('Equasis',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: widget.onEquasisFetch != null
                                      ? AppColors.teal
                                      : AppColors.textTertiary,
                                )),
                          ]),
                        ),
                      ),
                    ),
            ),
          ],
        ),

        _PickerField(
          label: 'Vessel Type',
          value: widget.vesselType,
          hint: 'Select vessel type',
          options: _vesselTypes,
          onChanged: widget.onVesselTypeChanged,
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Registration',
          icon: Icons.flag_outlined,
          color: AppColors.midBlue,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'Flag',
          controller: widget.flagCtrl,
          hint: 'e.g. Australia',
          onChanged: (_) => widget.onChanged(),
        ),
        SurveyField(
          label: 'Port of Registry',
          controller: widget.portCtrl,
          hint: 'e.g. Dampier',
          onChanged: (_) => widget.onChanged(),
        ),
        Row(children: [
          Expanded(
            child: SurveyField(
              label: 'Call Sign',
              controller: widget.callSignCtrl,
              hint: 'e.g. VRKU6',
              capitalization: TextCapitalization.characters,
              onChanged: (_) => widget.onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SurveyField(
              label: 'MMSI',
              controller: widget.mmsiCtrl,
              hint: 'e.g. 477123456',
              keyboard: TextInputType.number,
              onChanged: (_) => widget.onChanged(),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Ownership',
          icon: Icons.business_outlined,
          color: AppColors.amber,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'Owners',
          controller: widget.ownersCtrl,
          hint: 'e.g. MinRes Marine Pty Ltd',
          onChanged: (_) => widget.onChanged(),
        ),
        SurveyField(
          label: 'Operators',
          controller: widget.operatorsCtrl,
          hint: 'If different from owners',
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Classification',
          icon: Icons.verified_outlined,
          color: AppColors.purple,
        ),
        const SizedBox(height: 12),
        _PickerField(
          label: 'Class Society',
          value: widget.classSociety,
          hint: 'Select classification society',
          options: _classSocieties,
          onChanged: widget.onClassSocietyChanged,
        ),
        SurveyField(
          label: 'Class Notation',
          controller: widget.notationCtrl,
          hint: 'e.g. A1, ATB, Towing vessel, AMS',
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Build',
          icon: Icons.factory_outlined,
          color: AppColors.coral,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SurveyField(
            label: 'Year Built',
            controller: widget.yearBuiltCtrl,
            hint: 'e.g. 2007',
            keyboard: TextInputType.number,
            onChanged: (_) => widget.onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(child: SurveyField(
            label: 'Build Country',
            controller: widget.buildCountryCtrl,
            hint: 'e.g. Hong Kong',
            onChanged: (_) => widget.onChanged(),
          )),
        ]),
        SurveyField(
          label: 'Build Yard',
          controller: widget.buildYardCtrl,
          hint: 'e.g. Hin Lee Shipyard',
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Tab 2: Dimensions ─────────────────────────────────────────────────────────

class _DimensionsTab extends StatelessWidget {
  const _DimensionsTab({
    required this.gtCtrl,
    required this.ntCtrl,
    required this.dwtCtrl,
    required this.holdsCtrl,
    required this.tanksCtrl,
    required this.vesselType,
    required this.loaCtrl,
    required this.lbpCtrl,
    required this.breadthCtrl,
    required this.depthCtrl,
    required this.draftCtrl,
    required this.speedCtrl,
    required this.breadthQualifier,
    required this.draftQualifier,
    required this.onChanged,
    required this.onBreadthQualifierChanged,
    required this.onDraftQualifierChanged,
  });

  final TextEditingController gtCtrl, ntCtrl, dwtCtrl;
  final TextEditingController holdsCtrl, tanksCtrl;
  final String? vesselType;
  final TextEditingController loaCtrl, lbpCtrl, breadthCtrl, depthCtrl, draftCtrl;
  final TextEditingController speedCtrl;
  final String? breadthQualifier;
  final String? draftQualifier;
  final VoidCallback onChanged;
  final ValueChanged<String?> onBreadthQualifierChanged;
  final ValueChanged<String?> onDraftQualifierChanged;

  bool get _isTanker => _tankerTypes.contains(vesselType);
  bool get _isCargo  => _cargoTypes.contains(vesselType);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VesselSectionHeader(
          title: 'Tonnage',
          icon: Icons.scale_outlined,
          color: AppColors.teal,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SurveyField(
            label: 'Gross Tonnage (GT)',
            controller: gtCtrl,
            hint: 'e.g. 1311',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(child: SurveyField(
            label: 'Net Tonnage (NT)',
            controller: ntCtrl,
            hint: 'e.g. 393',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
        ]),
        SurveyField(
          label: 'Deadweight (DWT) — tonnes',
          controller: dwtCtrl,
          hint: 'e.g. 1100',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
        ),
        if (_isCargo)
          SurveyField(
            label: 'Number of Holds',
            controller: holdsCtrl,
            hint: 'e.g. 5',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          ),
        if (_isTanker)
          SurveyField(
            label: 'Number of Cargo Tanks',
            controller: tanksCtrl,
            hint: 'e.g. 12',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Principal Dimensions',
          icon: Icons.straighten_outlined,
          color: AppColors.midBlue,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SurveyField(
            label: 'Length OA (m)',
            controller: loaCtrl,
            hint: 'e.g. 75.30',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(child: SurveyField(
            label: 'Length BP (m)',
            controller: lbpCtrl,
            hint: 'e.g. 68.00',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
        ]),

        // Breadth with qualifier
        SurveyField(
          label: 'Breadth (m)',
          controller: breadthCtrl,
          hint: 'e.g. 16.80',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
        ),
        _ChipSelector(
          label: 'Breadth Qualifier',
          options: _breadthQualifiers,
          selected: breadthQualifier,
          onSelected: onBreadthQualifierChanged,
        ),
        const SizedBox(height: 12),

        SurveyField(
          label: 'Depth (m)',
          controller: depthCtrl,
          hint: 'e.g. 7.20',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
        ),

        // Draft with qualifier
        SurveyField(
          label: 'Draft (m)',
          controller: draftCtrl,
          hint: 'e.g. 5.80',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
        ),
        _ChipSelector(
          label: 'Draft Qualifier',
          options: _draftQualifiers,
          selected: draftQualifier,
          onSelected: onDraftQualifierChanged,
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Performance',
          icon: Icons.speed_outlined,
          color: AppColors.coral,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'Loaded Service Speed (knots)',
          controller: speedCtrl,
          hint: 'e.g. 12.5',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Tab 3: Machinery ──────────────────────────────────────────────────────────

class _MachineryTab extends ConsumerWidget {
  const _MachineryTab({
    required this.vesselId,
    required this.caseId,
    required this.propulsionType,
    required this.propellerType,
    required this.propulsionDriveType,
    required this.mcrPowerUnit,
    required this.mcrValueCtrl,
    required this.mcrRpmCtrl,
    required this.onPropulsionTypeChanged,
    required this.onPropellerTypeChanged,
    required this.onDriveTypeChanged,
    required this.onMcrUnitChanged,
    required this.onChanged,
  });

  final String vesselId;
  final String caseId;
  final String? propulsionType;
  final String? propellerType;
  final String? propulsionDriveType;
  final String mcrPowerUnit;
  final TextEditingController mcrValueCtrl;
  final TextEditingController mcrRpmCtrl;
  final ValueChanged<String?> onPropulsionTypeChanged;
  final ValueChanged<String?> onPropellerTypeChanged;
  final ValueChanged<String?> onDriveTypeChanged;
  final ValueChanged<String> onMcrUnitChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineryAsync = ref.watch(machineryProvider(vesselId));

    return machineryAsync.when(
      loading: () => const AppLoadingWidget(message: 'Loading machinery...'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (machinery) => CustomScrollView(
        slivers: [
          // ── Propulsion Particulars (fixed) ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VesselSectionHeader(
                    title: 'Propulsion Particulars',
                    icon: Icons.settings_input_component_outlined,
                    color: AppColors.midBlue,
                  ),
                  const SizedBox(height: 14),

                  _ChipSelector(
                    label: 'Propulsion Type',
                    options: _propulsionTypes,
                    selected: propulsionType,
                    onSelected: onPropulsionTypeChanged,
                  ),
                  const SizedBox(height: 12),

                  _PickerField(
                    label: 'Propeller / Thruster Type',
                    value: propellerType,
                    hint: 'Select propeller type',
                    options: _propellerTypes,
                    onChanged: onPropellerTypeChanged,
                  ),

                  _ChipSelector(
                    label: 'Propulsion Drive Type',
                    options: _propulsionDriveTypes,
                    selected: propulsionDriveType,
                    onSelected: onDriveTypeChanged,
                  ),
                  const SizedBox(height: 12),

                  // MCR row: value + unit toggle + RPM
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      flex: 3,
                      child: SurveyField(
                        label: 'MCR Power',
                        controller: mcrValueCtrl,
                        hint: 'e.g. 4500',
                        keyboard: TextInputType.number,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _UnitToggle(
                        value: mcrPowerUnit,
                        options: const ['kW', 'bhp'],
                        onChanged: onMcrUnitChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SurveyField(
                        label: 'MCR RPM',
                        controller: mcrRpmCtrl,
                        hint: 'e.g. 120',
                        keyboard: TextInputType.number,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  const VesselSectionHeader(
                    title: 'Machinery & Equipment',
                    icon: Icons.settings_outlined,
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // ── Dynamic machinery list ────────────────────────────────────
          if (machinery.isEmpty)
            const SliverToBoxAdapter(child: _MachineryEmptyInline())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: machinery.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => MachineryCard(
                  machinery: machinery[i],
                  caseId: caseId,
                  onEdit: () => _showAddEdit(context, ref,
                      vesselId: vesselId, existing: machinery[i]),
                  onDelete: () => _confirmDelete(context, ref, machinery[i]),
                ),
              ),
            ),

          // ── Add button ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddEdit(context, ref, vesselId: vesselId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Machinery / Equipment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEdit(BuildContext context, WidgetRef ref,
      {required String vesselId, MachineryModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMachinerySheet(
        vesselId: vesselId,
        caseId: caseId,
        existing: existing,
        onSave: (m) async {
          if (existing != null) {
            await ref.read(machineryProvider(vesselId).notifier).updateMachinery(m);
          } else {
            await ref.read(machineryProvider(vesselId).notifier).addMachinery(m);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, MachineryModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete machinery?'),
        content: Text('Remove ${m.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(machineryProvider(m.vesselId).notifier).deleteMachinery(m.machineryId);
    }
  }
}

class _MachineryEmptyInline extends StatelessWidget {
  const _MachineryEmptyInline();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No machinery recorded yet.\nAdd main engines, generators, thrusters…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

class _MachineryPlaceholder extends StatelessWidget {
  const _MachineryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Save vessel identity first to add machinery',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

/// Styled tappable field that opens a searchable bottom sheet for picking.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary, letterSpacing: 0.3)),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () => _openPicker(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: value != null ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, size: 18, color: AppColors.textTertiary),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet(
        title: label,
        options: options,
        selected: value,
        onSelected: (picked) {
          Navigator.pop(context);
          onChanged(picked);
        },
        onClear: () {
          Navigator.pop(context);
          onChanged(null);
        },
      ),
    );
  }
}

/// Bottom sheet with search bar, scrollable option list, and custom entry support.
class _SearchPickerSheet extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.onClear,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.options
            : widget.options.where((o) => o.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasCustom {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return false;
    return !widget.options.any((o) => o.toLowerCase() == q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) {
        final keyboardPad = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardPad),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search or type a custom value…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.midBlue, width: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (widget.selected != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.clear, color: AppColors.textTertiary, size: 18),
                  title: const Text('Clear selection',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  onTap: widget.onClear,
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _filtered.length + (_hasCustom ? 1 : 0),
                  itemBuilder: (_, i) {
                    // Custom "use as entered" row at the top
                    if (_hasCustom && i == 0) {
                      final custom = _searchCtrl.text.trim();
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.add_circle_outline,
                            color: AppColors.teal, size: 18),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textPrimary),
                            children: [
                              const TextSpan(text: 'Use "',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              TextSpan(text: custom,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.teal)),
                              const TextSpan(text: '"',
                                  style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        onTap: () => widget.onSelected(custom),
                      );
                    }
                    final opt = _filtered[_hasCustom ? i - 1 : i];
                    final isSelected = opt == widget.selected;
                    return ListTile(
                      dense: true,
                      title: Text(opt,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.midBlue
                                  : AppColors.textPrimary)),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.midBlue, size: 18)
                          : null,
                      onTap: () => widget.onSelected(opt),
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Horizontal scrollable choice chips for short option lists.
class _ChipSelector extends StatelessWidget {
  const _ChipSelector({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary, letterSpacing: 0.3)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final isSelected = opt == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onSelected(isSelected ? null : opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightBlue : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.midBlue : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(opt,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppColors.midBlue : AppColors.textSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle between two unit options (e.g. kW / bhp).
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt == value;
          return GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.midBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(opt,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
