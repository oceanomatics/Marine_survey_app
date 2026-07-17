// lib/features/vessel/screens/vessel_particulars_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/vessel_provider.dart';
import 'vessel_compliance_screen.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/cases_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../settings/providers/account_provider.dart';
import '../../../core/api/equasis_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/error_handler.dart';
import '../../../shared/widgets/chip_row.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../widgets/machinery_card.dart';
import '../widgets/add_machinery_sheet.dart';
import '../widgets/section_header.dart';
import '../widgets/survey_field.dart';
import '../../../shared/widgets/save_bar.dart';
import '../../photos/providers/photo_provider.dart';
import '../../photos/models/photo_model.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';
import '../../../shared/widgets/drive_photo_image.dart';
import '../../../core/api/supabase_client.dart';
import '../../../shared/widgets/back_app_bar.dart';

// ── ABL London H&M Report template option lists ───────────────────────────────

const _vesselTypes = [
  'General Cargo Ship',
  'Oil Tanker',
  'Products Carrier',
  'Ro Ro',
  'Passenger Ferry',
  'Offshore Support Vessel',
  'Offshore Supply Vessel',
  'Container Ship',
  'Anchor Handling Tug',
  'Tug',
  'Bulk Carrier',
  'Chemical Tanker',
  'Container Carrier',
  'Reefer Vessel',
  'LNG Carrier',
  'LPG Carrier',
  'Oceanographic Research Vessel',
  'Seismic Survey Vessel',
  'Dive Support Vessel',
  'Tender',
  'Crew Boat',
  'Cable Layer',
  'Pipe Layer',
  'Work Boat',
  'Pilot Boat',
  'Private Yacht',
  'Sailing Vessel',
];

const _classSocieties = [
  'American Bureau of Shipping',
  'Bureau Veritas',
  'DNV GL',
  'Lloyds Register of Shipping',
  'Nippon Kaiji Kyokai',
  'R.I.N.A.',
  'China Classification Society',
  'Russian Maritime Register of Shipping',
  'Korean Register of Shipping',
  'Polish Register of Shipping',
  'Indian Register of Shipping',
  'Croatian Register of Shipping',
  'A.B.S.',
  'B.V.',
  'C.C.S.',
  'C.R.S',
  'I.R.S',
  'K.R.S.',
  'L.R.S.',
  'N.K.K.',
  'R.M.R.S',
  'P.R.S',
];

// Propulsion Particulars reorganised into three independent fields (14 July
// 2026 walkthrough §3 Q5) — the old lists conflated screw count with prime
// mover type ("single screw, motor driven"...) and again with thruster type,
// forcing one combined choice instead of three genuinely separate facts.
const _primeMoverTypes = ['Motor', 'Steam', 'Electric'];

const _thrusterTypes = [
  'Fixed pitch',
  'Variable pitch',
  'Azipods',
  'Waterjet',
];

const _tankerTypes = {
  'oil tanker',
  'products carrier',
  'chemical tanker',
  'LNG carrier',
  'LPG carrier',
  'Reefer vessel',
};

const _cargoTypes = {
  'general cargo ship',
  'bulk carrier',
  'container ship',
  'container carrier',
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
  final _nameCtrl = TextEditingController();
  final _prevNameCtrl = TextEditingController();
  final _imoCtrl = TextEditingController();
  final _callSignCtrl = TextEditingController();
  final _mmsiCtrl = TextEditingController();
  final _flagCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _gtCtrl = TextEditingController();
  final _ntCtrl = TextEditingController();
  final _dwtCtrl = TextEditingController();
  final _loaCtrl = TextEditingController();
  final _lbpCtrl = TextEditingController();
  // Breadth/draft — independent fields per variant (§2.17 finding #12),
  // replacing the old single value + forced-choice qualifier dropdown.
  final _breadthMouldedCtrl = TextEditingController();
  final _breadthExtremeCtrl = TextEditingController();
  final _beamOaCtrl = TextEditingController();
  final _depthCtrl = TextEditingController();
  final _draftLoadLineCtrl = TextEditingController();
  final _draftMaxCtrl = TextEditingController();
  final _yearBuiltCtrl = TextEditingController();
  final _buildYardCtrl = TextEditingController();
  final _buildCountryCtrl = TextEditingController();
  final _ownersCtrl = TextEditingController();
  final _operatorsCtrl = TextEditingController();
  final _notationCtrl = TextEditingController();
  final _speedCtrl = TextEditingController();
  final _holdsCtrl = TextEditingController();
  final _tanksCtrl = TextEditingController();
  final _mcrValueCtrl = TextEditingController();
  final _mcrRpmCtrl = TextEditingController();
  final _screwCountCtrl = TextEditingController();
  // Fields moved to Identity tab
  final _officialNumberCtrl = TextEditingController();
  // TODO.md §2.11: registered_owner has existed on VesselModel since the
  // statutory-fields work but never had an editor UI anywhere — added here,
  // next to Official Number on the Registration tab, since both are
  // registration-document concepts.
  final _registeredOwnerCtrl = TextEditingController();
  final _constructionStandardCtrl = TextEditingController();
  final _piClubCtrl = TextEditingController();
  // Regulatory Standard / AMSA DCV fields (Identity tab)
  final _uviCtrl = TextEditingController();
  final _surveyCertNoCtrl = TextEditingController();
  RegulatoryStandard? _regulatoryStandard;
  AmsaVesselUseClass? _amsaVesselUseClass;
  AmsaServiceCategory? _amsaServiceCategory;
  HullMaterial? _hullMaterial;
  DateTime? _equipmentSurveyDue;
  DateTime? _hullSurveyDue;
  DateTime? _tailShaftSurveyDue;

  // Dropdown / chip selections
  String? _vesselType;
  String? _classSociety;
  // "Type of Prime Mover" (Motor/Steam/Electric) in the UI — see
  // _primeMoverTypes.
  String? _propulsionType;
  // "Thruster Type" (Fixed pitch/Variable pitch/Azipods/Waterjet) in the UI
  // — see _thrusterTypes.
  String? _propellerType;
  String _mcrPowerUnit = 'kW';

  String? _vesselId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _nameCtrl,
      _prevNameCtrl,
      _imoCtrl,
      _callSignCtrl,
      _mmsiCtrl,
      _flagCtrl,
      _portCtrl,
      _gtCtrl,
      _ntCtrl,
      _dwtCtrl,
      _loaCtrl,
      _lbpCtrl,
      _breadthMouldedCtrl,
      _breadthExtremeCtrl,
      _beamOaCtrl,
      _depthCtrl,
      _draftLoadLineCtrl,
      _draftMaxCtrl,
      _yearBuiltCtrl,
      _buildYardCtrl,
      _buildCountryCtrl,
      _ownersCtrl,
      _operatorsCtrl,
      _notationCtrl,
      _speedCtrl,
      _holdsCtrl,
      _tanksCtrl,
      _mcrValueCtrl,
      _mcrRpmCtrl,
      _screwCountCtrl,
      _officialNumberCtrl,
      _registeredOwnerCtrl,
      _constructionStandardCtrl,
      _piClubCtrl,
      _uviCtrl,
      _surveyCertNoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFields(VesselModel v) {
    _vesselId = v.vesselId;
    _nameCtrl.text = v.name;
    _prevNameCtrl.text = v.previousName ?? '';
    _imoCtrl.text = v.imoNumber ?? '';
    _callSignCtrl.text = v.callSign ?? '';
    _mmsiCtrl.text = v.mmsi ?? '';
    _vesselType = v.vesselType;
    _flagCtrl.text = v.flag ?? '';
    _portCtrl.text = v.portOfRegistry ?? '';
    _gtCtrl.text = v.grossTonnage?.toString() ?? '';
    _ntCtrl.text = v.netTonnage?.toString() ?? '';
    _dwtCtrl.text = v.deadweight?.toString() ?? '';
    _holdsCtrl.text = v.holdsCount?.toString() ?? '';
    _tanksCtrl.text = v.tanksCount?.toString() ?? '';
    _loaCtrl.text = v.lengthOa?.toString() ?? '';
    _lbpCtrl.text = v.lengthBp?.toString() ?? '';
    // Independent breadth fields — prefer the new per-variant columns; fall
    // back to the legacy single value/qualifier pair for vessels saved
    // before this split (§2.17 finding #12), so old data stays visible.
    _breadthMouldedCtrl.text = v.breadthMoulded?.toString() ??
        (v.breadthQualifier == 'Moulded Breadth'
            ? v.breadth?.toString() ?? ''
            : '');
    _breadthExtremeCtrl.text = v.breadthExtreme?.toString() ??
        (v.breadthQualifier == 'Extreme Breadth'
            ? v.breadth?.toString() ?? ''
            : '');
    _beamOaCtrl.text = v.beamOa?.toString() ??
        (v.breadthQualifier != null &&
                v.breadthQualifier != 'Moulded Breadth' &&
                v.breadthQualifier != 'Extreme Breadth'
            ? v.breadth?.toString() ?? ''
            : '');
    _depthCtrl.text = v.depth?.toString() ?? '';
    _draftLoadLineCtrl.text = v.draftLoadLine?.toString() ??
        (v.draftQualifier == 'Load Line Draft'
            ? v.maxDraft?.toString() ?? ''
            : '');
    _draftMaxCtrl.text = v.draftMax?.toString() ??
        (v.draftQualifier != 'Load Line Draft'
            ? v.maxDraft?.toString() ?? ''
            : '');
    _yearBuiltCtrl.text = v.yearBuilt?.toString() ?? '';
    _buildYardCtrl.text = v.buildYard ?? '';
    _buildCountryCtrl.text = v.buildCountry ?? '';
    _ownersCtrl.text = v.owners ?? '';
    _operatorsCtrl.text = v.operators ?? '';
    _classSociety = v.classSociety;
    _notationCtrl.text = v.classNotation ?? '';
    _speedCtrl.text = v.serviceSpeed?.toString() ?? '';
    _propulsionType = v.propulsionType;
    _propellerType = v.propellerType;
    _mcrValueCtrl.text = v.mcrPowerValue?.toString() ?? '';
    _mcrRpmCtrl.text = v.mcrRpm?.toString() ?? '';
    _mcrPowerUnit = v.mcrPowerUnit ?? 'kW';
    _screwCountCtrl.text = v.screwCount?.toString() ?? '';
    _officialNumberCtrl.text = v.officialNumber ?? '';
    _registeredOwnerCtrl.text = v.registeredOwner ?? '';
    _constructionStandardCtrl.text = v.constructionStandard ?? '';
    _piClubCtrl.text = v.piClub ?? '';
    _regulatoryStandard = v.regulatoryStandard;
    _amsaVesselUseClass = v.amsaVesselUseClass;
    _amsaServiceCategory = v.amsaServiceCategory;
    _hullMaterial = v.hullMaterial;
    _uviCtrl.text = v.uniqueVesselIdentifier ?? '';
    _surveyCertNoCtrl.text = v.surveyCertificateNo ?? '';
    _equipmentSurveyDue = v.equipmentSurveyDue;
    _hullSurveyDue = v.hullSurveyDue;
    _tailShaftSurveyDue = v.tailShaftSurveyDue;
  }

  Map<String, dynamic> _collectFields() => {
        'name': _nameCtrl.text.trim(),
        'previous_name': _prevNameCtrl.text.trim().isEmpty
            ? null
            : _prevNameCtrl.text.trim(),
        'imo_number':
            _imoCtrl.text.trim().isEmpty ? null : _imoCtrl.text.trim(),
        'call_sign': _callSignCtrl.text.trim().isEmpty
            ? null
            : _callSignCtrl.text.trim(),
        'mmsi': _mmsiCtrl.text.trim().isEmpty ? null : _mmsiCtrl.text.trim(),
        'vessel_type': _vesselType,
        'flag': _flagCtrl.text.trim().isEmpty ? null : _flagCtrl.text.trim(),
        'port_of_registry':
            _portCtrl.text.trim().isEmpty ? null : _portCtrl.text.trim(),
        'gross_tonnage': double.tryParse(_gtCtrl.text.trim()),
        'net_tonnage': double.tryParse(_ntCtrl.text.trim()),
        'deadweight': double.tryParse(_dwtCtrl.text.trim()),
        'holds_count': int.tryParse(_holdsCtrl.text.trim()),
        'tanks_count': int.tryParse(_tanksCtrl.text.trim()),
        'length_oa': double.tryParse(_loaCtrl.text.trim()),
        'length_bp': double.tryParse(_lbpCtrl.text.trim()),
        ..._collectBreadthDraftFields(),
        'depth': double.tryParse(_depthCtrl.text.trim()),
        'year_built': int.tryParse(_yearBuiltCtrl.text.trim()),
        'build_yard': _buildYardCtrl.text.trim().isEmpty
            ? null
            : _buildYardCtrl.text.trim(),
        'build_country': _buildCountryCtrl.text.trim().isEmpty
            ? null
            : _buildCountryCtrl.text.trim(),
        'owners':
            _ownersCtrl.text.trim().isEmpty ? null : _ownersCtrl.text.trim(),
        'operators': _operatorsCtrl.text.trim().isEmpty
            ? null
            : _operatorsCtrl.text.trim(),
        'class_society': _classSociety,
        'class_notation': _notationCtrl.text.trim().isEmpty
            ? null
            : _notationCtrl.text.trim(),
        'service_speed': double.tryParse(_speedCtrl.text.trim()),
        'screw_count': int.tryParse(_screwCountCtrl.text.trim()),
        'propulsion_type': _propulsionType,
        'propeller_type': _propellerType,
        'mcr_power_value': double.tryParse(_mcrValueCtrl.text.trim()),
        'mcr_rpm': int.tryParse(_mcrRpmCtrl.text.trim()),
        'mcr_power_unit': _mcrPowerUnit,
        'official_number': _officialNumberCtrl.text.trim().isEmpty
            ? null
            : _officialNumberCtrl.text.trim(),
        'registered_owner': _registeredOwnerCtrl.text.trim().isEmpty
            ? null
            : _registeredOwnerCtrl.text.trim(),
        'construction_standard': _constructionStandardCtrl.text.trim().isEmpty
            ? null
            : _constructionStandardCtrl.text.trim(),
        'pi_club':
            _piClubCtrl.text.trim().isEmpty ? null : _piClubCtrl.text.trim(),
        'regulatory_standard': _regulatoryStandard?.value,
        'amsa_vessel_use_class': _amsaVesselUseClass?.value,
        'amsa_service_category': _amsaServiceCategory?.value,
        'hull_material': _hullMaterial?.value,
        'unique_vessel_identifier':
            _uviCtrl.text.trim().isEmpty ? null : _uviCtrl.text.trim(),
        'survey_certificate_no': _surveyCertNoCtrl.text.trim().isEmpty
            ? null
            : _surveyCertNoCtrl.text.trim(),
        'equipment_survey_due':
            _equipmentSurveyDue?.toIso8601String().split('T').first,
        'hull_survey_due': _hullSurveyDue?.toIso8601String().split('T').first,
        'tail_shaft_survey_due':
            _tailShaftSurveyDue?.toIso8601String().split('T').first,
      };

  /// Builds the breadth/draft columns to save: the new independent
  /// per-variant fields, plus a derived legacy `breadth`/`breadth_qualifier`
  /// and `max_draft`/`draft_qualifier` pair (priority order below) so
  /// existing report-builder/AI-extraction code that only knows about the
  /// single legacy pair keeps working unchanged (§2.17 finding #12).
  Map<String, dynamic> _collectBreadthDraftFields() {
    final moulded = double.tryParse(_breadthMouldedCtrl.text.trim());
    final extreme = double.tryParse(_breadthExtremeCtrl.text.trim());
    final beamOa = double.tryParse(_beamOaCtrl.text.trim());
    final loadLine = double.tryParse(_draftLoadLineCtrl.text.trim());
    final maxDraft = double.tryParse(_draftMaxCtrl.text.trim());

    double? legacyBreadth;
    String? legacyBreadthQualifier;
    if (moulded != null) {
      legacyBreadth = moulded;
      legacyBreadthQualifier = 'Moulded Breadth';
    } else if (extreme != null) {
      legacyBreadth = extreme;
      legacyBreadthQualifier = 'Extreme Breadth';
    } else if (beamOa != null) {
      legacyBreadth = beamOa;
      legacyBreadthQualifier = 'Beam (OA)';
    }

    double? legacyDraft;
    String? legacyDraftQualifier;
    if (loadLine != null) {
      legacyDraft = loadLine;
      legacyDraftQualifier = 'Load Line Draft';
    } else if (maxDraft != null) {
      legacyDraft = maxDraft;
      legacyDraftQualifier = 'Max Draft';
    }

    return {
      'breadth_moulded': moulded,
      'breadth_extreme': extreme,
      'beam_oa': beamOa,
      'breadth': legacyBreadth,
      'breadth_qualifier': legacyBreadthQualifier,
      'draft_load_line': loadLine,
      'draft_max': maxDraft,
      'max_draft': legacyDraft,
      'draft_qualifier': legacyDraftQualifier,
    };
  }

  Future<void> _syncCaseTitle(String vesselName) async {
    try {
      final caseRow = await SupabaseService.client
          .from('cases')
          .select('technical_file_no, case_type')
          .eq('case_id', widget.caseId)
          .single();
      final jobNo = (caseRow['technical_file_no'] as String? ?? '').trim();
      final caseTypeLabel = caseRow['case_type'] != null
          ? CaseType.fromValue(caseRow['case_type'] as String).label
          : '';
      // Primary (or, failing that, the first) occurrence — mirrors
      // CaseNotifier._rebuildTitle so the occurrence brief is always
      // re-appended, even when no occurrence is flagged is_primary.
      final occRows = await SupabaseService.client
          .from('occurrences')
          .select('title, is_primary, occurrence_no')
          .eq('case_id', widget.caseId)
          .order('is_primary', ascending: false)
          .order('occurrence_no')
          .limit(1);
      final occTitle = (occRows as List).isNotEmpty
          ? ((occRows.first as Map)['title'] as String? ?? '').trim()
          : '';
      final parts = [jobNo, vesselName.trim(), caseTypeLabel, occTitle]
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        await SupabaseService.client
            .from('cases')
            .update({'title': parts.join(' – ')}).eq('case_id', widget.caseId);
      }
    } catch (_) {}
  }

  /// Entry point for the Save button. Checks the typed IMO against the
  /// database *before* creating or updating anything — if it already
  /// belongs to a different vessel, offers to link this case to that
  /// existing record and load its data, instead of hitting a conflict
  /// after a new (blank) vessel has already been created for this case.
  Future<void> _handleSave(String? vesselId) async {
    final imo = _imoCtrl.text.trim();
    if (imo.isNotEmpty) {
      final existing = await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .findVesselByImo(imo, excludeVesselId: vesselId);
      if (existing != null) {
        final existingName = (existing.name?.isNotEmpty ?? false)
            ? existing.name!
            : 'this vessel';
        if (!mounted) return;
        final shouldLink = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Vessel already on file'),
            content: Text(
              'IMO $imo is already recorded for "$existingName". '
              'Link this case to that record and load its existing '
              'particulars? Anything typed on this screen will be replaced.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Link & Load'),
              ),
            ],
          ),
        );
        if (shouldLink != true) return;

        setState(() => _saving = true);
        try {
          await ref
              .read(vesselForCaseProvider(widget.caseId).notifier)
              .linkExistingVessel(
                caseId: widget.caseId,
                existingVesselId: existing.vesselId,
              );
          setState(() => _hasChanges = false);
          ref.invalidate(caseProvider(widget.caseId));
          ref.invalidate(casesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Linked to "$existingName" — data loaded'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e, st) {
          if (mounted) {
            showError(context, 'Link failed: $e',
                error: e, stack: st, tag: 'Vessel');
          }
        } finally {
          if (mounted) setState(() => _saving = false);
        }
        return;
      }
    }

    if (vesselId != null) {
      await _save(vesselId);
    } else {
      await _createAndSave();
    }
  }

  Future<void> _save(String vesselId) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(vesselForCaseProvider(widget.caseId).notifier)
          .saveVessel(vesselId: vesselId, fields: _collectFields());
      await _syncCaseTitle(_nameCtrl.text);
      setState(() => _hasChanges = false);
      ref.invalidate(caseProvider(widget.caseId));
      ref.invalidate(casesProvider);
      if (mounted) {
        showSavedToast(context, label: 'Vessel particulars saved');
      }
    } on ImoConflictException catch (e) {
      if (mounted) showError(context, e.toString(), tag: 'Vessel');
    } catch (e, st) {
      if (mounted) {
        showError(context, 'Save failed: $e',
            error: e, stack: st, tag: 'Vessel');
      }
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
      await _syncCaseTitle(_nameCtrl.text);
      setState(() {
        _vesselId = vessel.vesselId;
        _hasChanges = false;
      });
      ref.invalidate(caseProvider(widget.caseId));
      ref.invalidate(casesProvider);
      if (mounted) {
        showSavedToast(context, label: 'Vessel particulars saved');
      }
    } on ImoConflictException catch (e) {
      if (mounted) showError(context, e.toString(), tag: 'Vessel');
    } catch (e, st) {
      if (mounted) {
        showError(context, 'Save failed: $e',
            error: e, stack: st, tag: 'Vessel');
      }
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
          ..showSnackBar(
              const SnackBar(content: Text('Enter an IMO number first')));
      }
      return;
    }

    // Wait for the account to finish loading rather than bailing out —
    // ref.read() only returns a snapshot, and accountProvider is often
    // still mid-load the first time this screen is used in a session.
    AccountState account;
    try {
      account = await ref.read(accountProvider.future);
    } catch (e) {
      _fetchingEquasis = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Could not load account: $e')));
      }
      return;
    }
    final equasisAcc = account.equasisAccount;
    if (equasisAcc == null) {
      _fetchingEquasis = false;
      if (!mounted) return;
      final router = GoRouter.of(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Text('No Equasis account configured'),
          action: SnackBarAction(
              label: 'Set up', onPressed: () => router.go('/account')),
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
        showSavedToast(context, label: 'Equasis report saved to Document Vault');
      }
    } catch (e, st) {
      if (mounted) {
        showError(context, 'Equasis fetch failed: $e',
            error: e, stack: st, tag: 'Vessel');
      }
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
        appBar: const BackAppBar(title: Text('Vessel Particulars')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load vessel data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(vesselForCaseProvider(widget.caseId)),
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
      appBar: BackAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vessel Particulars'),
            if (vessel != null)
              Text(
                vessel.name,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Identity & Ownership'),
            Tab(text: 'Registration & Insurance'),
            Tab(text: 'Classification'),
            Tab(text: 'Dimensions'),
            Tab(text: 'Machinery'),
          ],
        ),
      ),
      bottomNavigationBar: SaveBar(
        visible: _hasChanges || vesselId == null,
        saving: _saving,
        onSave: () => _handleSave(vesselId),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _IdentityOwnershipTab(
            caseId: widget.caseId,
            nameCtrl: _nameCtrl,
            prevNameCtrl: _prevNameCtrl,
            imoCtrl: _imoCtrl,
            vesselType: _vesselType,
            ownersCtrl: _ownersCtrl,
            operatorsCtrl: _operatorsCtrl,
            yearBuiltCtrl: _yearBuiltCtrl,
            buildYardCtrl: _buildYardCtrl,
            buildCountryCtrl: _buildCountryCtrl,
            regulatoryStandard: _regulatoryStandard,
            onChanged: _markChanged,
            onVesselTypeChanged: (v) {
              setState(() {
                _vesselType = v;
                _hasChanges = true;
              });
            },
            onRegulatoryStandardChanged: (v) {
              setState(() {
                _regulatoryStandard = v;
                _hasChanges = true;
              });
            },
            onEquasisFetch: _fetchFromEquasis,
            fetchingEquasis: _fetchingEquasis,
          ),
          _RegistrationTab(
            flagCtrl: _flagCtrl,
            portCtrl: _portCtrl,
            callSignCtrl: _callSignCtrl,
            mmsiCtrl: _mmsiCtrl,
            officialNumberCtrl: _officialNumberCtrl,
            registeredOwnerCtrl: _registeredOwnerCtrl,
            piClubCtrl: _piClubCtrl,
            regulatoryStandard: _regulatoryStandard,
            amsaVesselUseClass: _amsaVesselUseClass,
            amsaServiceCategory: _amsaServiceCategory,
            hullMaterial: _hullMaterial,
            uviCtrl: _uviCtrl,
            surveyCertNoCtrl: _surveyCertNoCtrl,
            equipmentSurveyDue: _equipmentSurveyDue,
            hullSurveyDue: _hullSurveyDue,
            tailShaftSurveyDue: _tailShaftSurveyDue,
            onChanged: _markChanged,
            onAmsaVesselUseClassChanged: (v) {
              setState(() {
                _amsaVesselUseClass = v;
                _hasChanges = true;
              });
            },
            onAmsaServiceCategoryChanged: (v) {
              setState(() {
                _amsaServiceCategory = v;
                _hasChanges = true;
              });
            },
            onHullMaterialChanged: (v) {
              setState(() {
                _hullMaterial = v;
                _hasChanges = true;
              });
            },
            onEquipmentSurveyDueChanged: (v) {
              setState(() {
                _equipmentSurveyDue = v;
                _hasChanges = true;
              });
            },
            onHullSurveyDueChanged: (v) {
              setState(() {
                _hullSurveyDue = v;
                _hasChanges = true;
              });
            },
            onTailShaftSurveyDueChanged: (v) {
              setState(() {
                _tailShaftSurveyDue = v;
                _hasChanges = true;
              });
            },
          ),
          _ClassificationTab(
            caseId: widget.caseId,
            regulatoryStandard: _regulatoryStandard,
            classSociety: _classSociety,
            notationCtrl: _notationCtrl,
            onChanged: _markChanged,
            onClassSocietyChanged: (v) {
              setState(() {
                _classSociety = v;
                _hasChanges = true;
              });
            },
          ),
          _DimensionsTab(
            gtCtrl: _gtCtrl,
            ntCtrl: _ntCtrl,
            dwtCtrl: _dwtCtrl,
            holdsCtrl: _holdsCtrl,
            tanksCtrl: _tanksCtrl,
            vesselType: _vesselType,
            loaCtrl: _loaCtrl,
            lbpCtrl: _lbpCtrl,
            breadthMouldedCtrl: _breadthMouldedCtrl,
            breadthExtremeCtrl: _breadthExtremeCtrl,
            beamOaCtrl: _beamOaCtrl,
            depthCtrl: _depthCtrl,
            draftLoadLineCtrl: _draftLoadLineCtrl,
            draftMaxCtrl: _draftMaxCtrl,
            speedCtrl: _speedCtrl,
            onChanged: _markChanged,
          ),
          vessel?.vesselId != null
              ? _MachineryTab(
                  vesselId: vessel!.vesselId,
                  caseId: widget.caseId,
                  screwCountCtrl: _screwCountCtrl,
                  propulsionType: _propulsionType,
                  propellerType: _propellerType,
                  mcrPowerUnit: _mcrPowerUnit,
                  mcrValueCtrl: _mcrValueCtrl,
                  mcrRpmCtrl: _mcrRpmCtrl,
                  onPropulsionTypeChanged: (v) {
                    setState(() {
                      _propulsionType = v;
                      _hasChanges = true;
                    });
                  },
                  onPropellerTypeChanged: (v) {
                    setState(() {
                      _propellerType = v;
                      _hasChanges = true;
                    });
                  },
                  onMcrUnitChanged: (v) {
                    setState(() {
                      _mcrPowerUnit = v;
                      _hasChanges = true;
                    });
                  },
                  onChanged: _markChanged,
                )
              : const _MachineryPlaceholder(),
        ],
      ),
    );
  }
}

// ── Tab 1: Identity & Ownership ─────────────────────────────────────────────

class _IdentityOwnershipTab extends ConsumerStatefulWidget {
  const _IdentityOwnershipTab({
    required this.caseId,
    required this.nameCtrl,
    required this.prevNameCtrl,
    required this.imoCtrl,
    required this.vesselType,
    required this.ownersCtrl,
    required this.operatorsCtrl,
    required this.yearBuiltCtrl,
    required this.buildYardCtrl,
    required this.buildCountryCtrl,
    required this.regulatoryStandard,
    required this.onChanged,
    required this.onVesselTypeChanged,
    required this.onRegulatoryStandardChanged,
    this.onEquasisFetch,
    this.fetchingEquasis = false,
  });

  final String caseId;
  final TextEditingController nameCtrl, prevNameCtrl, imoCtrl;
  final String? vesselType;
  final TextEditingController ownersCtrl, operatorsCtrl;
  final TextEditingController yearBuiltCtrl, buildYardCtrl, buildCountryCtrl;
  final RegulatoryStandard? regulatoryStandard;
  final VoidCallback onChanged;
  final ValueChanged<String?> onVesselTypeChanged;
  final ValueChanged<RegulatoryStandard?> onRegulatoryStandardChanged;
  final VoidCallback? onEquasisFetch;
  final bool fetchingEquasis;

  @override
  ConsumerState<_IdentityOwnershipTab> createState() =>
      _IdentityOwnershipTabState();
}

class _IdentityOwnershipTabState
    extends ConsumerState<_IdentityOwnershipTab> {
  // The vessel "general view" photo is the same single case-wide cover
  // photo shared with the Photo Gallery and Report Builder — picking one
  // here updates it everywhere, and vice versa.
  Future<void> _pickVesselPhoto() async {
    final picked = await showModalBottomSheet<List<PhotoModel>>(
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
    await ref
        .read(photosProvider(widget.caseId).notifier)
        .updateAllocation(picked.first.id, PhotoAllocation.coverPage);
  }

  Future<void> _openMarineTraffic() async {
    final imo = widget.imoCtrl.text.trim();
    if (imo.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Enter an IMO number first')));
      return;
    }
    await launchUrl(
      Uri.parse('https://www.marinetraffic.com/en/ais/details/ships/imo:$imo'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosProvider(widget.caseId)).value ?? [];
    final vesselPhoto = photos.coverPhoto;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Vessel general view photo ──────────────────────────────
        if (vesselPhoto != null)
          GestureDetector(
            onTap: _pickVesselPhoto,
            child: SizedBox(
              width: double.infinity,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DrivePhotoImage(
                  photo: vesselPhoto,
                  fit: BoxFit.cover,
                  noSourceBuilder: (_) => Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(Icons.cloud_download_outlined,
                          color: AppColors.textTertiary),
                    ),
                  ),
                  errorBuilder: (_) => Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.textTertiary),
                    ),
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
        SurveyField(
          label: 'Previous Name',
          controller: widget.prevNameCtrl,
          hint: 'Former name, if applicable',
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
                      width: 36,
                      height: 36,
                      child: Center(
                          child: SizedBox(
                        width: 16,
                        height: 16,
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
                            Icon(Icons.travel_explore,
                                size: 15,
                                color: widget.onEquasisFetch != null
                                    ? AppColors.teal
                                    : AppColors.textTertiary),
                            const SizedBox(width: 5),
                            Text('Equasis',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.onEquasisFetch != null
                                      ? AppColors.teal
                                      : AppColors.textTertiary,
                                )),
                          ]),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Tooltip(
                message: 'Show in MarineTraffic',
                child: InkWell(
                  onTap: _openMarineTraffic,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lightAmber,
                      border: Border.all(color: AppColors.amber),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.radar, size: 15, color: AppColors.amber),
                      SizedBox(width: 5),
                      Text('MarineTraffic',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amber,
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
        const SizedBox(height: 14),

        const Text('Regulatory Standard',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        ChipRow<RegulatoryStandard>(
          values: RegulatoryStandard.values,
          selected: widget.regulatoryStandard,
          label: (s) => s.label,
          onChanged: widget.onRegulatoryStandardChanged,
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
          title: 'Build',
          icon: Icons.factory_outlined,
          color: AppColors.coral,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: SurveyField(
            label: 'Year Built',
            controller: widget.yearBuiltCtrl,
            hint: 'e.g. 2007',
            keyboard: TextInputType.number,
            onChanged: (_) => widget.onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: SurveyField(
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

// ── Tab 2: Registration ───────────────────────────────────────────────────────

class _RegistrationTab extends StatelessWidget {
  const _RegistrationTab({
    required this.flagCtrl,
    required this.portCtrl,
    required this.callSignCtrl,
    required this.mmsiCtrl,
    required this.officialNumberCtrl,
    required this.registeredOwnerCtrl,
    required this.piClubCtrl,
    required this.regulatoryStandard,
    required this.amsaVesselUseClass,
    required this.amsaServiceCategory,
    required this.hullMaterial,
    required this.uviCtrl,
    required this.surveyCertNoCtrl,
    required this.equipmentSurveyDue,
    required this.hullSurveyDue,
    required this.tailShaftSurveyDue,
    required this.onChanged,
    required this.onAmsaVesselUseClassChanged,
    required this.onAmsaServiceCategoryChanged,
    required this.onHullMaterialChanged,
    required this.onEquipmentSurveyDueChanged,
    required this.onHullSurveyDueChanged,
    required this.onTailShaftSurveyDueChanged,
  });

  final TextEditingController flagCtrl, portCtrl;
  final TextEditingController callSignCtrl, mmsiCtrl;
  final TextEditingController officialNumberCtrl;
  final TextEditingController registeredOwnerCtrl;
  final TextEditingController piClubCtrl;
  final RegulatoryStandard? regulatoryStandard;
  final AmsaVesselUseClass? amsaVesselUseClass;
  final AmsaServiceCategory? amsaServiceCategory;
  final HullMaterial? hullMaterial;
  final TextEditingController uviCtrl;
  final TextEditingController surveyCertNoCtrl;
  final DateTime? equipmentSurveyDue;
  final DateTime? hullSurveyDue;
  final DateTime? tailShaftSurveyDue;
  final VoidCallback onChanged;
  final ValueChanged<AmsaVesselUseClass?> onAmsaVesselUseClassChanged;
  final ValueChanged<AmsaServiceCategory?> onAmsaServiceCategoryChanged;
  final ValueChanged<HullMaterial?> onHullMaterialChanged;
  final ValueChanged<DateTime?> onEquipmentSurveyDueChanged;
  final ValueChanged<DateTime?> onHullSurveyDueChanged;
  final ValueChanged<DateTime?> onTailShaftSurveyDueChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        Row(children: [
          Expanded(
            child: SurveyField(
              label: 'Call Sign',
              controller: callSignCtrl,
              hint: 'e.g. VRKU6',
              capitalization: TextCapitalization.characters,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SurveyField(
              label: 'MMSI',
              controller: mmsiCtrl,
              hint: 'e.g. 477123456',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
        ]),
        SurveyField(
          label: 'Official Number',
          controller: officialNumberCtrl,
          hint: 'National registration number',
          onChanged: (_) => onChanged(),
        ),
        SurveyField(
          label: 'Registered Owner',
          controller: registeredOwnerCtrl,
          hint: 'Name on the certificate of registry',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 20),

        // Insurance — moved here from Classification (14 July 2026
        // walkthrough: P&I Club was misplaced there, wanted as its own
        // standalone subsection on Registration).
        const VesselSectionHeader(
          title: 'Insurance',
          icon: Icons.shield_outlined,
          color: AppColors.teal,
        ),
        const SizedBox(height: 12),
        SurveyField(
          label: 'P&I Club',
          controller: piClubCtrl,
          hint: 'e.g. Gard, Skuld, West of England',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 20),

        // DCV — National Law only: AMSA-specific registration fields.
        if (regulatoryStandard == RegulatoryStandard.dcv) ...[
          const VesselSectionHeader(
            title: 'DCV Particulars',
            icon: Icons.anchor_outlined,
            color: AppColors.teal,
          ),
          const SizedBox(height: 12),
          const Text('Hull Material',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          ChipRow<HullMaterial>(
            values: HullMaterial.values,
            selected: hullMaterial,
            label: (m) => m.label,
            onChanged: onHullMaterialChanged,
          ),
          const SizedBox(height: 14),
          SurveyField(
            label: 'Unique Vessel Identifier',
            controller: uviCtrl,
            hint: 'AMSA UVI',
            onChanged: (_) => onChanged(),
          ),
          SurveyField(
            label: 'Survey Certificate No.',
            controller: surveyCertNoCtrl,
            hint: 'e.g. COS-12345-01',
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 6),
          const Text('AMSA Vessel Use Class',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          ChipRow<AmsaVesselUseClass>(
            values: AmsaVesselUseClass.values,
            selected: amsaVesselUseClass,
            label: (c) => c.label,
            onChanged: onAmsaVesselUseClassChanged,
          ),
          const SizedBox(height: 12),
          const Text('Service Category',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          ChipRow<AmsaServiceCategory>(
            values: AmsaServiceCategory.values,
            selected: amsaServiceCategory,
            label: (c) => c.label,
            onChanged: onAmsaServiceCategoryChanged,
          ),
          if (amsaVesselUseClass != null && amsaServiceCategory != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Class ${amsaVesselUseClass!.value}'
                '${amsaServiceCategory!.value.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal),
              ),
            ),
          const SizedBox(height: 14),
          _DatePickerField(
            label: 'Equipment Due',
            value: equipmentSurveyDue,
            onChanged: onEquipmentSurveyDueChanged,
          ),
          _DatePickerField(
            label: 'Hull Due',
            value: hullSurveyDue,
            onChanged: onHullSurveyDueChanged,
          ),
          _DatePickerField(
            label: 'Tail Shaft Due',
            value: tailShaftSurveyDue,
            onChanged: onTailShaftSurveyDueChanged,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Tab 3: Classification ─────────────────────────────────────────────────────

class _ClassificationTab extends StatelessWidget {
  const _ClassificationTab({
    required this.caseId,
    required this.regulatoryStandard,
    required this.classSociety,
    required this.notationCtrl,
    required this.onChanged,
    required this.onClassSocietyChanged,
  });

  final String caseId;
  final RegulatoryStandard? regulatoryStandard;
  final String? classSociety;
  final TextEditingController notationCtrl;
  final VoidCallback onChanged;
  final ValueChanged<String?> onClassSocietyChanged;

  @override
  Widget build(BuildContext context) {
    // Class society/notation/P&I club apply to Convention vessels — shown by
    // default (regulatoryStandard == null covers pre-existing vessels) and
    // not applicable once DCV (National Law) is selected.
    final applies = regulatoryStandard != RegulatoryStandard.dcv;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VesselSectionHeader(
          title: 'Classification',
          icon: Icons.verified_outlined,
          color: AppColors.purple,
        ),
        const SizedBox(height: 4),
        const Text(
          'Static identity data only — which class society and notation the '
          'vessel holds. Certificates, conditions of class, drydocking, PSC '
          'and ISPS (things that change during the survey) live on '
          'Certificates & Class at case level, not here.',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        if (!applies)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Not applicable — this vessel operates under National Law '
              '(DCV), see the Registration tab for DCV particulars.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic),
            ),
          )
        else ...[
          _PickerField(
            label: 'Class Society',
            value: classSociety,
            hint: 'Select classification society',
            options: _classSocieties,
            onChanged: onClassSocietyChanged,
          ),
          SurveyField(
            label: 'Class Notation',
            controller: notationCtrl,
            hint: 'e.g. A1, ATB, Towing vessel, AMS',
            onChanged: (_) => onChanged(),
          ),
        ],
        const SizedBox(height: 20),
        // Link to the case-level Certificates & Class screen — sits below the
        // static class fields (16 July 2026 bug report: was above them).
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VesselComplianceScreen(caseId: caseId))),
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text('Open Certificates & Class'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.purple,
              side: const BorderSide(color: AppColors.purple),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Tab 4: Dimensions ─────────────────────────────────────────────────────────

/// Small-caps sub-header for the Longitudinal/Transversal/Vertical groups
/// within Principal Dimensions — lighter than [VesselSectionHeader], which
/// is sized for the tab's top-level sections (Tonnage/Principal
/// Dimensions/Performance), not a third-level grouping inside one of them.
class _DimensionGroupLabel extends StatelessWidget {
  const _DimensionGroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.midBlue,
      ),
    );
  }
}

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
    required this.breadthMouldedCtrl,
    required this.breadthExtremeCtrl,
    required this.beamOaCtrl,
    required this.depthCtrl,
    required this.draftLoadLineCtrl,
    required this.draftMaxCtrl,
    required this.speedCtrl,
    required this.onChanged,
  });

  final TextEditingController gtCtrl, ntCtrl, dwtCtrl;
  final TextEditingController holdsCtrl, tanksCtrl;
  final String? vesselType;
  final TextEditingController loaCtrl, lbpCtrl, depthCtrl;
  // Independent breadth/draft fields (§2.17 finding #12) — the old design
  // forced picking a single qualifier for one shared value; moulded/extreme
  // breadth and beam (OA), and load line/max draft, are genuinely different
  // measurements collected from different documents, so each gets its own
  // field and is filled in as it becomes available.
  final TextEditingController breadthMouldedCtrl, breadthExtremeCtrl;
  final TextEditingController beamOaCtrl;
  final TextEditingController draftLoadLineCtrl, draftMaxCtrl;
  final TextEditingController speedCtrl;
  final VoidCallback onChanged;

  bool get _isTanker => _tankerTypes.contains(vesselType);
  bool get _isCargo => _cargoTypes.contains(vesselType);

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
          Expanded(
              child: SurveyField(
            label: 'Gross Tonnage (GT)',
            controller: gtCtrl,
            hint: 'e.g. 1311',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: SurveyField(
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

        // Regrouped into Longitudinal / Transversal / Vertical (14 July
        // 2026 walkthrough §3 Q3 — the previous flat list, plus a full-width
        // Moulded Breadth field breaking the half-width pattern of its
        // siblings, made the tab feel disorganised). Every field stays
        // half-width for a compact, aligned grid; an unpaired third field in
        // a group gets an invisible filler so the grid doesn't skew.
        const _DimensionGroupLabel('LONGITUDINAL'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: SurveyField(
            label: 'Length OA (m)',
            controller: loaCtrl,
            hint: 'e.g. 75.30',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: SurveyField(
            label: 'Length BP (m)',
            controller: lbpCtrl,
            hint: 'e.g. 68.00',
            keyboard: TextInputType.number,
            onChanged: (_) => onChanged(),
          )),
        ]),
        const SizedBox(height: 16),

        const _DimensionGroupLabel('TRANSVERSAL'),
        const SizedBox(height: 4),
        // Breadth — independent fields, fill in whichever were collected.
        const Text(
          'Fill in whichever breadth figures were collected — not every '
          'document states all three.',
          style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SurveyField(
              label: 'Moulded Breadth (m)',
              controller: breadthMouldedCtrl,
              hint: 'e.g. 16.80',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SurveyField(
              label: 'Extreme Breadth (m)',
              controller: breadthExtremeCtrl,
              hint: 'e.g. 17.10',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SurveyField(
              label: 'Beam (OA) (m)',
              controller: beamOaCtrl,
              hint: 'e.g. 16.80',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 16),

        const _DimensionGroupLabel('VERTICAL'),
        const SizedBox(height: 4),
        // Draft — independent fields, same rationale as breadth above.
        const Text(
          'Fill in whichever draft figures were collected.',
          style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SurveyField(
              label: 'Depth (m)',
              controller: depthCtrl,
              hint: 'e.g. 7.20',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SurveyField(
              label: 'Load Line Draft (m)',
              controller: draftLoadLineCtrl,
              hint: 'e.g. 5.80',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SurveyField(
              label: 'Max Draft (m)',
              controller: draftMaxCtrl,
              hint: 'e.g. 6.10',
              keyboard: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox()),
        ]),
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

// ── Tab 5: Machinery ──────────────────────────────────────────────────────────

class _MachineryTab extends ConsumerWidget {
  const _MachineryTab({
    required this.vesselId,
    required this.caseId,
    required this.screwCountCtrl,
    required this.propulsionType,
    required this.propellerType,
    required this.mcrPowerUnit,
    required this.mcrValueCtrl,
    required this.mcrRpmCtrl,
    required this.onPropulsionTypeChanged,
    required this.onPropellerTypeChanged,
    required this.onMcrUnitChanged,
    required this.onChanged,
  });

  final String vesselId;
  final String caseId;
  final TextEditingController screwCountCtrl;
  /// "Type of Prime Mover" in the UI (Motor / Steam / Electric) — see
  /// _primeMoverTypes.
  final String? propulsionType;
  /// "Thruster Type" in the UI (Fixed pitch / Variable pitch / Azipods /
  /// Waterjet) — see _thrusterTypes.
  final String? propellerType;
  final String mcrPowerUnit;
  final TextEditingController mcrValueCtrl;
  final TextEditingController mcrRpmCtrl;
  final ValueChanged<String?> onPropulsionTypeChanged;
  final ValueChanged<String?> onPropellerTypeChanged;
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

                  // A single-digit value — constrain to ~a third width rather
                  // than a full-width field (16 July 2026 bug report).
                  Row(children: [
                    Expanded(
                      flex: 1,
                      child: SurveyField(
                        label: 'Number of Screws',
                        controller: screwCountCtrl,
                        hint: 'e.g. 1',
                        keyboard: TextInputType.number,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const Expanded(flex: 2, child: SizedBox()),
                  ]),
                  const SizedBox(height: 12),

                  _ChipSelector(
                    label: 'Type of Prime Mover',
                    options: _primeMoverTypes,
                    selected: propulsionType,
                    onSelected: onPropulsionTypeChanged,
                  ),
                  const SizedBox(height: 12),

                  _ChipSelector(
                    label: 'Thruster Type',
                    options: _thrusterTypes,
                    selected: propellerType,
                    onSelected: onPropellerTypeChanged,
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
                  // Stable key, not just position: the on-card nameplate
                  // scan (machinery_card.dart) awaits updateMachinery()
                  // *before* attachLink() — without a key, an in-place
                  // Machinery list rebuild during that await risks Flutter
                  // reusing the wrong Element for this index (or tearing
                  // down the one running the async flow), silently
                  // dropping the attachLink call with no visible error.
                  // The Edit-menu path (add_machinery_sheet.dart) doesn't
                  // hit this because it runs inside its own modal sheet,
                  // decoupled from this list's rebuilds — matching the
                  // reported "works via Edit menu, not via the tab" split
                  // (14 July 2026 walkthrough).
                  key: ValueKey(machinery[i].machineryId),
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
            await ref
                .read(machineryProvider(vesselId).notifier)
                .updateMachinery(m);
            return m;
          } else {
            return ref
                .read(machineryProvider(vesselId).notifier)
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

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? null
        : '${value!.day.toString().padLeft(2, '0')} '
            '${_mon(value!.month)} ${value!.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2040),
            );
            onChanged(picked);
          },
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
                  formatted ?? 'Select date',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary),
                ),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.textTertiary),
            ]),
          ),
        ),
      ]),
    );
  }

  static String _mon(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3)),
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
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more,
                    size: 18, color: AppColors.textTertiary),
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
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(children: [
              const SizedBox(height: 8),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                        borderSide: const BorderSide(
                            color: AppColors.midBlue, width: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (widget.selected != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.clear,
                      color: AppColors.textTertiary, size: 18),
                  title: const Text('Clear selection',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
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
                              const TextSpan(
                                  text: 'Use "',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                              TextSpan(
                                  text: custom,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.teal)),
                              const TextSpan(
                                  text: '"',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
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
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.midBlue
                                  : AppColors.textPrimary)),
                      trailing: isSelected
                          ? const Icon(Icons.check,
                              color: AppColors.midBlue, size: 18)
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          // Wrap, not a horizontally-scrolling Row: long option labels (e.g.
          // "single screw, steam turbine driven") were getting visually
          // cropped at the edge since the horizontal-scroll affordance
          // wasn't discoverable (14 July 2026 walkthrough).
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onSelected(isSelected ? null : opt),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.midBlue
                              : AppColors.textSecondary)),
                ),
              );
            }).toList(),
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
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
