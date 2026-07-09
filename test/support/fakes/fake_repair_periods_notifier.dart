// Widget-test double for RepairPeriodsNotifier — skips SupabaseService.client
// entirely so RepairPeriodsScreen can be pumped with ProviderScope overrides
// and no network/auth setup. Mirrors the pattern in fake_checklist_notifier.dart.
import 'package:marine_survey_app/features/survey/models/repair_period_model.dart';
import 'package:marine_survey_app/features/survey/providers/repair_period_provider.dart';

class FakeRepairPeriodsNotifier extends RepairPeriodsNotifier {
  FakeRepairPeriodsNotifier(this._seed);
  final List<RepairPeriodModel> _seed;

  @override
  Future<List<RepairPeriodModel>> build(String caseId) async => _seed;
}
