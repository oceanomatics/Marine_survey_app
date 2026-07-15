import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marine_survey_app/features/attendances/models/attendance_model.dart';
import 'package:marine_survey_app/features/attendances/providers/attendances_provider.dart';

class FakeAttendancesNotifier extends AttendancesNotifier {
  FakeAttendancesNotifier([this._visits = const []]);
  final List<SurveyAttendanceModel> _visits;
  int _counter = 0;

  @override
  Future<List<SurveyAttendanceModel>> build(String caseId) async => _visits;

  @override
  Future<SurveyAttendanceModel> add({
    required String caseId,
    required AttendanceType type,
    DateTime? date,
    String? location,
    double? latitude,
    double? longitude,
    SurveyLocationType? locationType,
    String? locationDetail,
    String? nearestPort,
    double? distanceOffshoreNm,
    String? surveyorName,
    VesselStatus? vesselStatus,
    String? summary,
  }) async {
    final created = SurveyAttendanceModel(
      attendanceId: 'fake-attendance-${++_counter}',
      caseId: caseId,
      attendanceType: type,
      attendanceDate: date,
      location: location,
      latitude: latitude,
      longitude: longitude,
      locationType: locationType,
      locationDetail: locationDetail,
      nearestPort: nearestPort,
      distanceOffshoreNm: distanceOffshoreNm,
      surveyorName: surveyorName,
      vesselStatus: vesselStatus,
      summary: summary,
    );
    final current = state.value ?? [];
    state = AsyncData([...current, created]);
    return created;
  }

  @override
  Future<void> delete(String attendanceId) async {
    final current = state.value ?? [];
    state = AsyncData(
        current.where((a) => a.attendanceId != attendanceId).toList());
  }
}
