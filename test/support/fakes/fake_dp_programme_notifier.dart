import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/dp/models/dp_models.dart';
import 'package:marine_survey_app/features/dp/providers/dp_programme_provider.dart';

/// Widget-test double for the DP trial-programme record.
class FakeDpProgrammeNotifier extends DpProgrammeNotifier {
  FakeDpProgrammeNotifier([this._seed]);
  final DpProgrammeModel? _seed;

  @override
  Future<DpProgrammeModel?> build(String caseId) async => _seed;

  DpProgrammeModel _current() =>
      state.value ??
      DpProgrammeModel(id: 'fake-prog', caseId: arg);

  @override
  Future<void> setOverallResult(DpOverallResult? result) async {
    final c = _current();
    state = AsyncData(DpProgrammeModel(
      id: c.id,
      caseId: c.caseId,
      applicableRules: c.applicableRules,
      operatingModes: c.operatingModes,
      overallResult: result,
      revision: c.revision,
    ));
  }

  @override
  Future<void> setOperatingModes(String modes) async {}

  @override
  Future<void> setApplicableRules(String rules) async {}

  @override
  Future<void> setRevision(int revision) async {
    final c = _current();
    state = AsyncData(DpProgrammeModel(
      id: c.id,
      caseId: c.caseId,
      applicableRules: c.applicableRules,
      operatingModes: c.operatingModes,
      overallResult: c.overallResult,
      revision: revision,
    ));
  }
}
