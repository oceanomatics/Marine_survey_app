// Widget-test doubles for the providers TimelineScreen aggregates from —
// attendances, damage, and surveyor notes (the last only so the embedded
// ContextCuesPanel can render). No Supabase. See fake_checklist_notifier.dart.

import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';
import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/surveyor_notes/models/surveyor_note_model.dart';
import 'package:marine_survey_app/features/surveyor_notes/providers/surveyor_notes_provider.dart';

class FakeAttendancesNotifier extends AttendancesNotifier {
  FakeAttendancesNotifier([this._seed = const []]);
  final List<SurveyAttendanceModel> _seed;
  @override
  Future<List<SurveyAttendanceModel>> build(String arg) async => _seed;
}

class FakeDamageNotifier extends DamageNotifier {
  FakeDamageNotifier(this._seed);
  final DamageState _seed;
  @override
  Future<DamageState> build(String caseId) async => _seed;
}

class FakeSurveyorNotesNotifier extends SurveyorNotesNotifier {
  FakeSurveyorNotesNotifier([this._seed = const []]);
  final List<SurveyorNote> _seed;
  @override
  Future<List<SurveyorNote>> build(String caseId) async => _seed;
}
