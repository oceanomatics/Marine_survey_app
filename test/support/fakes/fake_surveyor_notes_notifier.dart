// Widget-test double for SurveyorNotesNotifier — skips SupabaseService.client
// and sqflite entirely so any screen embedding ContextCuesPanel can be pumped
// with ProviderScope overrides and no network/auth/DB setup. Mirrors the
// pattern in fake_checklist_notifier.dart.
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

class FakeSurveyorNotesNotifier extends SurveyorNotesNotifier {
  FakeSurveyorNotesNotifier([this._seed = const []]);
  final List<SurveyorNote> _seed;

  @override
  Future<List<SurveyorNote>> build(String caseId) async => _seed;
}
