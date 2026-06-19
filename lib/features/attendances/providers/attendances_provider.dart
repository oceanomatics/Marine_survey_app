// lib/features/attendances/providers/attendances_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../../../core/api/supabase_client.dart';

final attendancesProvider = AsyncNotifierProviderFamily<AttendancesNotifier,
    List<SurveyAttendanceModel>, String>(
  AttendancesNotifier.new,
);

class AttendancesNotifier
    extends FamilyAsyncNotifier<List<SurveyAttendanceModel>, String> {
  @override
  Future<List<SurveyAttendanceModel>> build(String arg) => _fetch();

  Future<List<SurveyAttendanceModel>> _fetch() async {
    final data = await SupabaseService.client
        .from('survey_attendances')
        .select()
        .eq('case_id', arg)
        .order('created_at', ascending: true);
    return (data as List)
        .map((j) =>
            SurveyAttendanceModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<SurveyAttendanceModel> add({
    required String caseId,
    required AttendanceType type,
    DateTime? date,
    String? location,
    String? surveyorName,
    VesselStatus? vesselStatus,
    String? summary,
  }) async {
    final model = SurveyAttendanceModel(
      attendanceId: '',
      caseId: caseId,
      attendanceType: type,
      attendanceDate: date,
      location: location,
      surveyorName: surveyorName,
      vesselStatus: vesselStatus,
      summary: summary,
    );
    final inserted = await SupabaseService.client
        .from('survey_attendances')
        .insert(model.toInsertJson())
        .select()
        .single();
    final created = SurveyAttendanceModel.fromJson(inserted);
    final current = state.value ?? [];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> delete(String attendanceId) async {
    await SupabaseService.client
        .from('survey_attendances')
        .delete()
        .eq('attendance_id', attendanceId);
    final current = state.value ?? [];
    state = AsyncData(
        current.where((a) => a.attendanceId != attendanceId).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
