import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';

class FakeAttendancesNotifier extends AttendancesNotifier {
  FakeAttendancesNotifier([this._visits = const []]);
  final List<SurveyAttendanceModel> _visits;

  @override
  Future<List<SurveyAttendanceModel>> build(String caseId) async => _visits;
}
