// Widget-test double for DamageNotifier — skips SupabaseService.client
// entirely so screens embedding damageProvider can be pumped with
// ProviderScope overrides and no network/auth setup. Mirrors the pattern in
// fake_checklist_notifier.dart.
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';

class FakeDamageNotifier extends DamageNotifier {
  FakeDamageNotifier(this._seed);
  final DamageState _seed;

  @override
  Future<DamageState> build(String caseId) async => _seed;
}
