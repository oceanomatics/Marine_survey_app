import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/pi/models/pi_models.dart';
import 'package:marine_survey_app/features/pi/providers/pi_injured_party_provider.dart';

/// Widget-test double for the P&I Injured Parties register.
class FakePiInjuredPartyNotifier extends PiInjuredPartyNotifier {
  FakePiInjuredPartyNotifier([this._seed = const []]);
  final List<PiInjuredPartyModel> _seed;
  int _counter = 0;

  @override
  Future<List<PiInjuredPartyModel>> build(String caseId) async => _seed;

  @override
  Future<PiInjuredPartyModel> add({
    String? personRole,
    String? personName,
    String? condition,
    String? infoSource,
  }) async {
    final p = PiInjuredPartyModel(
      id: 'fake-ip-${++_counter}',
      caseId: arg,
      personRole: personRole,
      personName: personName,
      condition: condition,
      infoSource: infoSource,
    );
    state = AsyncData([...(state.value ?? []), p]);
    return p;
  }

  @override
  Future<void> updateFields(String id,
      {String? personRole,
      String? personName,
      String? condition,
      String? infoSource}) async {
    state = AsyncData((state.value ?? [])
        .map((p) => p.id == id
            ? p.copyWith(
                personRole: personRole,
                personName: personName,
                condition: condition,
                infoSource: infoSource)
            : p)
        .toList());
  }

  @override
  Future<void> delete(String id) async {
    state = AsyncData((state.value ?? []).where((p) => p.id != id).toList());
  }
}
