// Widget-test double for VesselForCaseNotifier — skips SupabaseService.client
// and replays the same optimistic-update shape as the real notifier (see
// vessel_provider.dart) so VesselParticularsScreen can be pumped without any
// network/auth setup.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';

class FakeVesselForCaseNotifier extends VesselForCaseNotifier {
  FakeVesselForCaseNotifier(this._seed, {this.imoConflict});
  final VesselModel? _seed;
  /// If set, saveVessel()/createAndSave() throws ImoConflictException
  /// whenever the typed IMO matches this value.
  final ({String imo, String vesselId, String? name})? imoConflict;

  int _counter = 0;

  @override
  Future<VesselModel?> build(String caseId) async => _seed;

  @override
  Future<({String vesselId, String? name})?> findVesselByImo(
    String imoNumber, {
    String? excludeVesselId,
  }) async {
    final conflict = imoConflict;
    if (conflict != null &&
        conflict.imo == imoNumber &&
        conflict.vesselId != excludeVesselId) {
      return (vesselId: conflict.vesselId, name: conflict.name);
    }
    return null;
  }

  @override
  Future<VesselModel> createVessel({
    required String caseId,
    required String name,
  }) async {
    final vessel = VesselModel(vesselId: 'fake-vessel-${++_counter}', name: name);
    state = AsyncData(vessel);
    return vessel;
  }

  @override
  Future<void> saveVessel({
    required String vesselId,
    required Map<String, dynamic> fields,
  }) async {
    final current = state.value;
    final merged = <String, dynamic>{
      'vessel_id': vesselId,
      if (current != null) ...current.toJson(),
      ...fields,
    };
    state = AsyncData(VesselModel.fromJson(merged));
  }

  @override
  Future<VesselModel> linkExistingVessel({
    required String caseId,
    required String existingVesselId,
  }) async {
    final vessel = VesselModel(
      vesselId: existingVesselId,
      name: imoConflict?.name ?? 'Linked Vessel',
    );
    state = AsyncData(vessel);
    return vessel;
  }

  @override
  Future<void> refresh() async {
    // No-op — nothing to refetch in a fake.
  }
}
