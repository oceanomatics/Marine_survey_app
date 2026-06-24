// lib/features/vessel/providers/vessel_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cases/models/case_model.dart';
import '../../../core/api/supabase_client.dart';

/// Thrown by [VesselForCaseNotifier.saveVessel] when the supplied IMO number
/// is already assigned to a different vessel in the database.
class ImoConflictException implements Exception {
  const ImoConflictException(
      this.imoNumber, this.existingVesselId, this.existingVesselName);
  final String imoNumber;
  final String existingVesselId;
  final String? existingVesselName;

  @override
  String toString() =>
      'IMO $imoNumber is already assigned to vessel '
      '"${existingVesselName ?? existingVesselId}"';
}

// ── Vessel for a case ──────────────────────────────────────────────────────

final vesselForCaseProvider =
    AsyncNotifierProviderFamily<VesselForCaseNotifier, VesselModel?, String>(
  VesselForCaseNotifier.new,
);

class VesselForCaseNotifier extends FamilyAsyncNotifier<VesselModel?, String> {
  @override
  Future<VesselModel?> build(String caseId) => _fetch(caseId);

  Future<VesselModel?> _fetch(String caseId) async {
    // Get vessel_id from case
    final caseData = await SupabaseService.client
        .from('cases')
        .select('vessel_id')
        .eq('case_id', caseId)
        .single();

    final vesselId = caseData['vessel_id'] as String?;
    if (vesselId == null) return null;

    final data = await SupabaseService.client
        .from('vessels')
        .select()
        .eq('vessel_id', vesselId)
        .single();

    return VesselModel.fromJson(data);
  }

  /// Create a new vessel and link it to the case
  Future<VesselModel> createVessel({
    required String caseId,
    required String name,
  }) async {
    final data = await SupabaseService.client
        .from('vessels')
        .insert({'name': name})
        .select()
        .single();

    final vessel = VesselModel.fromJson(data);

    await SupabaseService.client
        .from('cases')
        .update({'vessel_id': vessel.vesselId}).eq('case_id', caseId);

    state = AsyncData(vessel);
    return vessel;
  }

  /// Save all vessel particulars fields.
  /// IMO is handled separately — if another vessel already owns the supplied
  /// IMO, [ImoConflictException] is thrown instead of hitting a 23505.
  Future<void> saveVessel({
    required String vesselId,
    required Map<String, dynamic> fields,
  }) async {
    final toUpdate = Map<String, dynamic>.from(fields);
    final rawImo   = toUpdate.remove('imo_number');
    final imoNumber = (rawImo as String? ?? '').trim();

    if (toUpdate.isNotEmpty) {
      await SupabaseService.client
          .from('vessels')
          .update(toUpdate)
          .eq('vessel_id', vesselId);
    }

    if (imoNumber.isNotEmpty) {
      final conflict = await SupabaseService.client
          .from('vessels')
          .select('vessel_id, name')
          .eq('imo_number', imoNumber)
          .neq('vessel_id', vesselId)
          .maybeSingle();

      if (conflict != null) {
        throw ImoConflictException(
          imoNumber,
          conflict['vessel_id'] as String,
          conflict['name'] as String?,
        );
      }

      await SupabaseService.client
          .from('vessels')
          .update({'imo_number': imoNumber})
          .eq('vessel_id', vesselId);
    }

    await refresh();
  }

  /// Apply AI-extracted data — merges over existing, surveyor confirms
  Future<VesselModel> applyExtraction({
    required String caseId,
    required String vesselId,
    required Map<String, dynamic> extracted,
  }) async {
    final current = state.value;
    if (current == null) return createVessel(caseId: caseId, name: 'TBC');

    final updated = current.applyExtraction(extracted);
    await SupabaseService.client
        .from('vessels')
        .update(updated.toJson())
        .eq('vessel_id', vesselId);

    state = AsyncData(updated);
    return updated;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

// ── Machinery for a vessel ─────────────────────────────────────────────────

final machineryProvider = AsyncNotifierProviderFamily<MachineryNotifier,
    List<MachineryModel>, String>(
  MachineryNotifier.new,
);

class MachineryNotifier
    extends FamilyAsyncNotifier<List<MachineryModel>, String> {
  @override
  Future<List<MachineryModel>> build(String vesselId) => _fetch(vesselId);

  Future<List<MachineryModel>> _fetch(String vesselId) async {
    final data = await SupabaseService.client
        .from('machinery')
        .select()
        .eq('vessel_id', vesselId)
        .order('role')
        .order('unit_number');
    return (data as List)
        .map((e) => MachineryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MachineryModel> addMachinery(MachineryModel m) async {
    final data = await SupabaseService.client
        .from('machinery')
        .insert(m.toInsertJson())
        .select()
        .single();
    final created = MachineryModel.fromJson(data);
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  Future<void> updateMachinery(MachineryModel m) async {
    await SupabaseService.client
        .from('machinery')
        .update(m.toInsertJson())
        .eq('machinery_id', m.machineryId);
    await refresh();
  }

  Future<void> deleteMachinery(String machineryId) async {
    await SupabaseService.client
        .from('machinery')
        .delete()
        .eq('machinery_id', machineryId);
    state = AsyncData(
      (state.value ?? []).where((m) => m.machineryId != machineryId).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

// ── Vessel Components Provider ─────────────────────────────────────────────
// arg = machineryId

final vesselComponentsProvider =
    AsyncNotifierProviderFamily<VesselComponentsNotifier,
        List<VesselComponentModel>, String>(
  VesselComponentsNotifier.new,
);

class VesselComponentsNotifier
    extends FamilyAsyncNotifier<List<VesselComponentModel>, String> {
  @override
  Future<List<VesselComponentModel>> build(String machineryId) =>
      _fetch(machineryId);

  Future<List<VesselComponentModel>> _fetch(String machineryId) async {
    try {
      final data = await SupabaseService.client
          .from('vessel_components')
          .select()
          .eq('machinery_id', machineryId)
          .order('sequence_no');
      return (data as List)
          .map((e) => VesselComponentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<VesselComponentModel> addComponent(
      VesselComponentModel component) async {
    final data = await SupabaseService.client
        .from('vessel_components')
        .insert(component.toInsertJson())
        .select()
        .single();
    final created = VesselComponentModel.fromJson(data);
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  Future<void> deleteComponent(String componentId) async {
    await SupabaseService.client
        .from('vessel_components')
        .delete()
        .eq('component_id', componentId);
    state = AsyncData(
      (state.value ?? [])
          .where((c) => c.componentId != componentId)
          .toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

// ── Vessel Component Model ─────────────────────────────────────────────────

class VesselComponentModel {
  const VesselComponentModel({
    required this.componentId,
    required this.machineryId,
    required this.vesselId,
    required this.name,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.dateOfManufacture,
    this.notes,
    this.sequenceNo = 1,
    this.createdAt,
  });

  final String componentId;
  final String machineryId;
  final String vesselId;
  final String name;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final String? dateOfManufacture;
  final String? notes;
  final int sequenceNo;
  final DateTime? createdAt;

  factory VesselComponentModel.fromJson(Map<String, dynamic> j) =>
      VesselComponentModel(
        componentId:       j['component_id'] as String,
        machineryId:       j['machinery_id'] as String,
        vesselId:          j['vessel_id'] as String,
        name:              j['name'] as String,
        manufacturer:      j['manufacturer'] as String?,
        model:             j['model'] as String?,
        serialNumber:      j['serial_number'] as String?,
        dateOfManufacture: j['date_of_manufacture'] as String?,
        notes:             j['notes'] as String?,
        sequenceNo:        j['sequence_no'] as int? ?? 1,
        createdAt:         j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'machinery_id': machineryId,
        'vessel_id':    vesselId,
        'name':         name,
        if (manufacturer != null)     'manufacturer':       manufacturer,
        if (model != null)            'model':              model,
        if (serialNumber != null)     'serial_number':      serialNumber,
        if (dateOfManufacture != null) 'date_of_manufacture': dateOfManufacture,
        if (notes != null)            'notes':              notes,
        'sequence_no': sequenceNo,
      };
}

// ── Machinery Model ────────────────────────────────────────────────────────

class MachineryModel {
  const MachineryModel({
    required this.machineryId,
    required this.vesselId,
    required this.machineryType,
    this.role,
    this.make,
    this.model,
    this.serialNumber,
    this.mcrKw,
    this.mcrRpm,
    this.fuelType,
    this.cylinderCount,
    this.configuration,
    this.quantity = 1,
    this.unitNumber,
    this.runHrsNew,
    this.runHrsOverhaul,
  });

  final String machineryId;
  final String vesselId;
  final String machineryType;
  final String? role;
  final String? make;
  final String? model;
  final String? serialNumber;
  final double? mcrKw;
  final double? mcrRpm;
  final String? fuelType;
  final int? cylinderCount;
  final String? configuration;
  final int quantity;
  final String? unitNumber;
  final double? runHrsNew;
  final double? runHrsOverhaul;

  factory MachineryModel.fromJson(Map<String, dynamic> j) => MachineryModel(
        machineryId: j['machinery_id'] as String,
        vesselId: j['vessel_id'] as String,
        machineryType: j['machinery_type'] as String,
        role: j['role'] as String?,
        make: j['make'] as String?,
        model: j['model'] as String?,
        serialNumber: j['serial_number'] as String?,
        mcrKw: (j['mcr_kw'] as num?)?.toDouble(),
        mcrRpm: (j['mcr_rpm'] as num?)?.toDouble(),
        fuelType: j['fuel_type'] as String?,
        cylinderCount: j['cylinder_count'] as int?,
        configuration: j['configuration'] as String?,
        quantity: j['quantity'] as int? ?? 1,
        unitNumber: j['unit_number'] as String?,
        runHrsNew: (j['run_hrs_new'] as num?)?.toDouble(),
        runHrsOverhaul: (j['run_hrs_overhaul'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertJson() => {
        'vessel_id': vesselId,
        'machinery_type': machineryType,
        if (role != null) 'role': role,
        if (make != null) 'make': make,
        if (model != null) 'model': model,
        if (serialNumber != null) 'serial_number': serialNumber,
        if (mcrKw != null) 'mcr_kw': mcrKw,
        if (mcrRpm != null) 'mcr_rpm': mcrRpm,
        if (fuelType != null) 'fuel_type': fuelType,
        if (cylinderCount != null) 'cylinder_count': cylinderCount,
        if (configuration != null) 'configuration': configuration,
        'quantity': quantity,
        if (unitNumber != null) 'unit_number': unitNumber,
        if (runHrsNew != null) 'run_hrs_new': runHrsNew,
        if (runHrsOverhaul != null) 'run_hrs_overhaul': runHrsOverhaul,
      };

  MachineryModel copyWith({
    String? make,
    String? model,
    String? serialNumber,
    double? mcrKw,
    double? mcrRpm,
    String? fuelType,
    int? cylinderCount,
    String? configuration,
    int? quantity,
    String? unitNumber,
    double? runHrsNew,
    double? runHrsOverhaul,
  }) =>
      MachineryModel(
        machineryId: machineryId,
        vesselId: vesselId,
        machineryType: machineryType,
        role: role,
        make: make ?? this.make,
        model: model ?? this.model,
        serialNumber: serialNumber ?? this.serialNumber,
        mcrKw: mcrKw ?? this.mcrKw,
        mcrRpm: mcrRpm ?? this.mcrRpm,
        fuelType: fuelType ?? this.fuelType,
        cylinderCount: cylinderCount ?? this.cylinderCount,
        configuration: configuration ?? this.configuration,
        quantity: quantity ?? this.quantity,
        unitNumber: unitNumber ?? this.unitNumber,
        runHrsNew: runHrsNew ?? this.runHrsNew,
        runHrsOverhaul: runHrsOverhaul ?? this.runHrsOverhaul,
      );

  String get displayName {
    final parts = <String>[];
    if (make != null) parts.add(make!);
    if (model != null) parts.add(model!);
    if (parts.isEmpty) parts.add(machineryType);
    if (unitNumber != null) parts.add('(No. $unitNumber)');
    return parts.join(' ');
  }

  String get roleLabel => switch (role) {
        'main_engine'         => 'Main Engine',
        'diesel_generator'    => 'Diesel Generator',
        'emergency_generator' => 'Emerg. Generator',
        'thruster'            => 'Thruster',
        'gearbox'             => 'Gearbox',
        'pump'                => 'Pump',
        'compressor'          => 'Compressor',
        'separator'           => 'Separator',
        'crane'               => 'Crane',
        _                     => 'Other',
      };
}
