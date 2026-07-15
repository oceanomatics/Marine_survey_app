// Widget-test double for PartiesNotifier — skips SupabaseService.client
// entirely. Mirrors fake_assured_contacts_notifier.dart etc.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/parties/models/party_model.dart';
import 'package:marine_survey_app/features/parties/providers/parties_provider.dart';

class FakePartiesNotifier extends PartiesNotifier {
  FakePartiesNotifier([this._seed]);
  final CasePartiesModel? _seed;

  @override
  Future<CasePartiesModel?> build(String arg) async => _seed;

  @override
  Future<void> save(CasePartiesModel model) async {
    state = AsyncData(model);
  }
}
