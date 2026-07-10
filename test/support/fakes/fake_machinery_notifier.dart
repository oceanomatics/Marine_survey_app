import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';

class FakeMachineryNotifier extends MachineryNotifier {
  FakeMachineryNotifier(this._seed);
  final List<MachineryModel> _seed;
  int _counter = 0;

  @override
  Future<List<MachineryModel>> build(String vesselId) async => _seed;

  @override
  Future<MachineryModel> addMachinery(MachineryModel m) async {
    final created = MachineryModel(
      machineryId: 'fake-machinery-${++_counter}',
      vesselId: m.vesselId,
      machineryType: m.machineryType,
      role: m.role,
      make: m.make,
      model: m.model,
      serialNumber: m.serialNumber,
      mcrKw: m.mcrKw,
      mcrRpm: m.mcrRpm,
      fuelType: m.fuelType,
      cylinderCount: m.cylinderCount,
      configuration: m.configuration,
      quantity: m.quantity,
      unitNumber: m.unitNumber,
      runHrsNew: m.runHrsNew,
      runHrsOverhaul: m.runHrsOverhaul,
    );
    state = AsyncData([...state.value ?? [], created]);
    return created;
  }

  @override
  Future<void> updateMachinery(MachineryModel m) async {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((e) => e.machineryId == m.machineryId ? m : e).toList(),
    );
  }

  @override
  Future<void> deleteMachinery(String machineryId) async {
    final current = state.value ?? [];
    state = AsyncData(
      current.where((e) => e.machineryId != machineryId).toList(),
    );
  }

  @override
  Future<void> refresh() async {}
}
