// lib/features/attendances/models/attendance_model.dart

import 'package:flutter/foundation.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum AttendanceType {
  initial('initial', 'Initial Attendance'),
  followUp('follow_up', 'Follow-up Attendance'),
  finalInspection('final_inspection', 'Final Inspection'),
  remoteReview('remote_review', 'Remote / Desk Review');

  const AttendanceType(this.value, this.label);
  final String value;
  final String label;

  static AttendanceType fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => AttendanceType.initial);
}

enum VesselStatus {
  alongside('alongside', 'Alongside'),
  atAnchor('at_anchor', 'At Anchor'),
  dryDocked('dry_docked', 'Dry Docked'),
  afloatOther('afloat_other', 'Afloat (Other)'),
  inTransit('in_transit', 'In Transit'),
  notApplicable('not_applicable', 'N/A — Remote Review');

  const VesselStatus(this.value, this.label);
  final String value;
  final String label;

  static VesselStatus fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => VesselStatus.notApplicable);
}

// ── Model ──────────────────────────────────────────────────────────────────

@immutable
class SurveyAttendanceModel {
  const SurveyAttendanceModel({
    required this.attendanceId,
    required this.caseId,
    required this.attendanceType,
    this.attendanceDate,
    this.location,
    this.surveyorName,
    this.vesselStatus,
    this.summary,
    this.createdAt,
  });

  final String attendanceId;
  final String caseId;
  final AttendanceType attendanceType;
  final DateTime? attendanceDate;
  final String? location;
  final String? surveyorName;
  final VesselStatus? vesselStatus;
  final String? summary;
  final DateTime? createdAt;

  factory SurveyAttendanceModel.fromJson(Map<String, dynamic> j) =>
      SurveyAttendanceModel(
        attendanceId:   j['attendance_id'] as String,
        caseId:         j['case_id'] as String,
        attendanceType: AttendanceType.fromValue(
            j['attendance_type'] as String? ?? 'initial'),
        attendanceDate: j['attendance_date'] != null
            ? DateTime.tryParse(j['attendance_date'] as String)
            : null,
        location:     j['location'] as String?,
        surveyorName: j['surveyor_name'] as String?,
        vesselStatus: j['vessel_status'] != null
            ? VesselStatus.fromValue(j['vessel_status'] as String)
            : null,
        summary:   j['summary'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':         caseId,
        'attendance_type': attendanceType.value,
        if (attendanceDate != null)
          'attendance_date': _fmtDate(attendanceDate!),
        if (location != null)     'location':      location,
        if (surveyorName != null) 'surveyor_name': surveyorName,
        if (vesselStatus != null) 'vessel_status': vesselStatus!.value,
        if (summary != null)      'summary':       summary,
      };

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
