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

  // ── Text controllers for all fields ───────────────────────────────────────
  final _nameCtrl         = TextEditingController();
  final _imoCtrl          = TextEditingController();
  final _typeCtrl         = TextEditingController();
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
  final _classCtrl        = TextEditingController();
  final _notationCtrl     = TextEditingController();
  final _speedCtrl        = TextEditingController();

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
      _nameCtrl, _imoCtrl, _typeCtrl, _flagCtrl, _portCtrl,
      _gtCtrl, _ntCtrl, _dwtCtrl, _loaCtrl, _lbpCtrl,
      _breadthCtrl, _depthCtrl, _draftCtrl, _yearBuiltCtrl,
      _buildYardCtrl, _buildCountryCtrl, _ownersCtrl, _operatorsCtrl,
      _classCtrl, _notationCtrl, _speedCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _populateFields(VesselModel v) {
    _vesselId = v.vesselId;
    _nameCtrl.text         = v.name;
    _imoCtrl.text          = v.imoNumber        ?? '';
    _typeCtrl.text         = v.vesselType        ?? '';
    _flagCtrl.text         = v.flag              ?? '';
    _portCtrl.text         = v.portOfRegistry    ?? '';
    _gtCtrl.text           = v.grossTonnage?.toString() ?? '';
    _ntCtrl.text           = v.netTonnage?.toString()   ?? '';
    _dwtCtrl.text          = v.deadweight?.toString()   ?? '';
    _loaCtrl.text          = v.lengthOa?.toString()     ?? '';
    _lbpCtrl.text          = v.lengthBp?.toString()     ?? '';
    _breadthCtrl.text      = v.breadth?.toString()      ?? '';
    _depthCtrl.text        = v.depth?.toString()        ?? '';
    _draftCtrl.text        = v.maxDraft?.toString()     ?? '';
    _yearBuiltCtrl.text    = v.yearBuilt?.toString()    ?? '';
    _buildYardCtrl.text    = v.buildYard         ?? '';
    _buildCountryCtrl.text = v.buildCountry      ?? '';
    _ownersCtrl.text       = v.owners            ?? '';
    _operatorsCtrl.text    = v.operators         ?? '';
    _classCtrl.text        = v.classSociety      ?? '';
    _notationCtrl.text     = v.classNotation     ?? '';
    _speedCtrl.text        = v.serviceSpeed?.toString() ?? '';
  }

  Map<String, dynamic> _collectFields() => {
    'name':             _nameCtrl.text.trim(),
    'imo_number':       _imoCtrl.text.trim().isEmpty   ? null : _imoCtrl.text.trim(),
    'vessel_type':      _typeCtrl.text.trim().isEmpty  ? null : _typeCtrl.text.trim(),
    'flag':             _flagCtrl.text.trim().isEmpty  ? null : _flagCtrl.text.trim(),
    'port_of_registry': _portCtrl.text.trim().isEmpty  ? null : _portCtrl.text.trim(),
    'gross_tonnage':    double.tryParse(_gtCtrl.text.trim()),
    'net_tonnage':      double.tryParse(_ntCtrl.text.trim()),
    'deadweight':       double.tryParse(_dwtCtrl.text.trim()),
    'length_oa':        double.tryParse(_loaCtrl.text.trim()),
    'length_bp':        double.tryParse(_lbpCtrl.text.trim()),
    'breadth':          double.tryParse(_breadthCtrl.text.trim()),
    'depth':            double.tryParse(_depthCtrl.text.trim()),
    'max_draft':        double.tryParse(_draftCtrl.text.trim()),
    'year_built':       int.tryParse(_yearBuiltCtrl.text.trim()),
    'build_yard':       _buildYardCtrl.text.trim().isEmpty    ? null : _buildYardCtrl.text.trim(),
    'build_country':    _buildCountryCtrl.text.trim().isEmpty ? null : _buildCountryCtrl.text.trim(),
    'owners':           _ownersCtrl.text.trim().isEmpty       ? null : _ownersCtrl.text.trim(),
    'operators':        _operatorsCtrl.text.trim().isEmpty    ? null : _operatorsCtrl.text.trim(),
    'class_society':    _classCtrl.text.trim().isEmpty        ? null : _classCtrl.text.trim(),
    'class_notation':   _notationCtrl.text.trim().isEmpty     ? null : _notationCtrl.text.trim(),
    'service_speed':    double.tryParse(_speedCtrl.text.trim()),
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
          .createVessel(
              caseId: widget.caseId, name: _nameCtrl.text.trim());
      await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .saveVessel(vesselId: vessel.vesselId, fields: _collectFields());
      setState(() { _vesselId = vessel.vesselId; _hasChanges = false; });

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
    final imo = _imoCtrl.text.trim();
    if (imo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an IMO number first')),
      );
      return;
    }

    final account = ref.read(accountProvider).value;
    final equasisAcc = account?.equasisAccount;
    if (equasisAcc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No Equasis account configured'),
          action: SnackBarAction(
            label: 'Account',
            onPressed: () => context.go('/account'),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _fetchingEquasis = true);
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
            category: DocCategory.classReport,
            willExtract: false,
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

  @override
  Widget build(BuildContext context) {
    final vesselAsync = ref.watch(vesselForCaseProvider(widget.caseId));

    return vesselAsync.when(
      loading: () => const Scaffold(body: AppLoadingWidget()),
      error: (e, _) => _buildScaffold(null, error: e.toString()),
      data: (vessel) {
        // Populate fields once when data first arrives
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

  Widget _buildScaffold(VesselModel? vessel, {String? error}) {
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
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7)),
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
        actions: [
          // Equasis fetch — visible only when IMO is set
          if (_imoCtrl.text.trim().isNotEmpty)
            _fetchingEquasis
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.travel_explore,
                        color: Colors.white),
                    tooltip: 'Fetch from Equasis',
                    onPressed: _fetchFromEquasis,
                  ),
          if (_hasChanges || vesselId == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => vesselId != null
                        ? _save(vesselId)
                        : _createAndSave(),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _IdentityTab(
            nameCtrl:         _nameCtrl,
            imoCtrl:          _imoCtrl,
            typeCtrl:         _typeCtrl,
            flagCtrl:         _flagCtrl,
            portCtrl:         _portCtrl,
            ownersCtrl:       _ownersCtrl,
            operatorsCtrl:    _operatorsCtrl,
            classCtrl:        _classCtrl,
            notationCtrl:     _notationCtrl,
            yearBuiltCtrl:    _yearBuiltCtrl,
            buildYardCtrl:    _buildYardCtrl,
            buildCountryCtrl: _buildCountryCtrl,
            onChanged: () => setState(() => _hasChanges = true),
          ),
          _DimensionsTab(
            gtCtrl:      _gtCtrl,
            ntCtrl:      _ntCtrl,
            dwtCtrl:     _dwtCtrl,
            loaCtrl:     _loaCtrl,
            lbpCtrl:     _lbpCtrl,
            breadthCtrl: _breadthCtrl,
            depthCtrl:   _depthCtrl,
            draftCtrl:   _draftCtrl,
            speedCtrl:   _speedCtrl,
            onChanged: () => setState(() => _hasChanges = true),
          ),
          vessel?.vesselId != null
              ? _MachineryTab(vesselId: vessel!.vesselId)
              : const _MachineryPlaceholder(),
        ],
      ),
    );
  }
}

// ── Tab 1: Identity ────────────────────────────────────────────────────────

class _IdentityTab extends StatelessWidget {
  const _IdentityTab({
    required this.nameCtrl,
    required this.imoCtrl,
    required this.typeCtrl,
    required this.flagCtrl,
    required this.portCtrl,
    required this.ownersCtrl,
    required this.operatorsCtrl,
    required this.classCtrl,
    required this.notationCtrl,
    required this.yearBuiltCtrl,
    required this.buildYardCtrl,
    required this.buildCountryCtrl,
    required this.onChanged,
  });

  final TextEditingController nameCtrl, imoCtrl, typeCtrl, flagCtrl, portCtrl;
  final TextEditingController ownersCtrl, operatorsCtrl, classCtrl, notationCtrl;
  final TextEditingController yearBuiltCtrl, buildYardCtrl, buildCountryCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VesselSectionHeader(
          title: 'Vessel Identity',
          icon: Icons.directions_boat_outlined,
          color: AppColors.teal,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'Vessel Name *',
          controller: nameCtrl,
          hint: 'e.g. MINRES ODIN',
          onChanged: (_) => onChanged(),
          capitalization: TextCapitalization.characters,
        ),
        SurveyField(
          label: 'IMO Number',
          controller: imoCtrl,
          hint: 'e.g. 9374935',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
        ),
        SurveyField(
          label: 'Vessel Type',
          controller: typeCtrl,
          hint: 'e.g. AHTS, Bulk Carrier, Tanker',
          onChanged: (_) => onChanged(),
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
          controller: flagCtrl,
          hint: 'e.g. Australia',
          onChanged: (_) => onChanged(),
        ),
        SurveyField(
          label: 'Port of Registry',
          controller: portCtrl,
          hint: 'e.g. Dampier',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Ownership',
          icon: Icons.business_outlined,
          color: AppColors.amber,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'Owners',
          controller: ownersCtrl,
          hint: 'e.g. MinRes Marine Pty Ltd',
          onChanged: (_) => onChanged(),
        ),
        SurveyField(
          label: 'Operators',
          controller: operatorsCtrl,
          hint: 'If different from owners',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Classification',
          icon: Icons.verified_outlined,
          color: AppColors.purple,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'Class Society',
          controller: classCtrl,
          hint: 'e.g. A.B.S., DNV, Lloyd\'s',
          onChanged: (_) => onChanged(),
        ),
        SurveyField(
          label: 'Class Notation',
          controller: notationCtrl,
          hint: 'e.g. A1, ATB, Towing vessel, AMS',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 20),

        const VesselSectionHeader(
          title: 'Build',
          icon: Icons.factory_outlined,
          color: AppColors.coral,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SurveyField(
                label: 'Year Built',
                controller: yearBuiltCtrl,
                hint: 'e.g. 2007',
                keyboard: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SurveyField(
                label: 'Build Country',
                controller: buildCountryCtrl,
                hint: 'e.g. Hong Kong',
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        SurveyField(
          label: 'Build Yard',
          controller: buildYardCtrl,
          hint: 'e.g. Hin Lee Shipyard',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Tab 2: Dimensions ─────────────────────────────────────────────────────

class _DimensionsTab extends StatelessWidget {
  const _DimensionsTab({
    required this.gtCtrl,
    required this.ntCtrl,
    required this.dwtCtrl,
    required this.loaCtrl,
    required this.lbpCtrl,
    required this.breadthCtrl,
    required this.depthCtrl,
    required this.draftCtrl,
    required this.speedCtrl,
    required this.onChanged,
  });

  final TextEditingController gtCtrl, ntCtrl, dwtCtrl;
  final TextEditingController loaCtrl, lbpCtrl, breadthCtrl, depthCtrl, draftCtrl;
  final TextEditingController speedCtrl;
  final VoidCallback onChanged;

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
        Row(children: [
          Expanded(child: SurveyField(
            label: 'Breadth (m)',
            controller: breadthCtrl,
            hint: 'e.g. 16.80',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(child: SurveyField(
            label: 'Depth (m)',
            controller: depthCtrl,
            hint: 'e.g. 7.20',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
        ]),
        SurveyField(
          label: 'Maximum Draft (m)',
          controller: draftCtrl,
          hint: 'e.g. 5.80',
          keyboard: TextInputType.number,
          onChanged: (_) => onChanged(),
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

// ── Tab 3: Machinery ──────────────────────────────────────────────────────

class _MachineryTab extends ConsumerWidget {
  const _MachineryTab({required this.vesselId});
  final String vesselId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineryAsync = ref.watch(machineryProvider(vesselId));

    return machineryAsync.when(
      loading: () => const AppLoadingWidget(message: 'Loading machinery...'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (machinery) => Column(
        children: [
          Expanded(
            child: machinery.isEmpty
                ? _MachineryEmpty(vesselId: vesselId)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: machinery.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => MachineryCard(
                      machinery: machinery[i],
                      onEdit: () => _showAddEdit(context, ref,
                          vesselId: vesselId, existing: machinery[i]),
                      onDelete: () => _confirmDelete(
                          context, ref, machinery[i]),
                    ),
                  ),
          ),
          // Add machinery button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showAddEdit(context, ref, vesselId: vesselId),
                icon: const Icon(Icons.add),
                label: const Text('Add Machinery / Equipment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal),
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
        existing: existing,
        onSave: (m) async {
          if (existing != null) {
            await ref.read(machineryProvider(vesselId).notifier)
                .updateMachinery(m);
          } else {
            await ref.read(machineryProvider(vesselId).notifier)
                .addMachinery(m);
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
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(machineryProvider(m.vesselId).notifier)
          .deleteMachinery(m.machineryId);
    }
  }
}

class _MachineryEmpty extends StatelessWidget {
  const _MachineryEmpty({required this.vesselId});
  final String vesselId;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.settings_outlined,
            size: 56, color: AppColors.textTertiary),
        SizedBox(height: 14),
        Text('No machinery recorded',
            style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        SizedBox(height: 6),
        Text('Add main engines, generators,\nthrusters and other equipment',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      ]),
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
