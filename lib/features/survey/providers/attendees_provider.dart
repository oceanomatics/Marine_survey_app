// lib/features/survey/providers/attendees_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/supabase_client.dart';

// ── Role types ─────────────────────────────────────────────────────────────

enum AttendeeRole {
  // Group 0 — Vessel representatives
  master('master', 'Master'),
  portCaptain('port_captain', 'Port Captain'),
  chiefEngineer('chief_engineer', 'Chief Engineer'),
  firstEngineer('first_engineer', 'First Engineer'),
  superintendent('superintendent', 'Superintendent'),
  ownerRep('owner_rep', 'Owner\'s Representative'),
  // Group 1 — Contractors
  serviceEngineer('service_engineer', 'Service Engineer'),
  other('other', 'Other'),
  // Group 2 — Class / other surveyors
  classSurveyor('class_surveyor', 'Class Surveyor'),
  adjuster('adjuster', 'Adjuster / Average Adjuster'),
  broker('broker', 'Broker'),
  solicitor('solicitor', 'Solicitor'),
  // Group 3 — Attending surveyor (us) — always last
  surveyor('surveyor', 'Surveyor');

  const AttendeeRole(this.value, this.label);
  final String value;
  final String label;

  /// Display-order priority: vessel reps → contractors → class/others → surveyor.
  int get sortOrder => switch (this) {
        master          => 0,
        portCaptain     => 1,
        chiefEngineer   => 2,
        firstEngineer   => 3,
        superintendent  => 4,
        ownerRep        => 5,
        serviceEngineer => 10,
        other           => 11,
        classSurveyor   => 20,
        adjuster        => 21,
        broker          => 22,
        solicitor       => 23,
        surveyor        => 30,
      };

  static AttendeeRole fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => AttendeeRole.other);
}

// ── Title (form of address) ─────────────────────────────────────────────────

enum AttendeeTitle {
  mr('mr', 'Mr.'),
  mrs('mrs', 'Mrs.'),
  ms('ms', 'Ms.'),
  miss('miss', 'Miss'),
  dr('dr', 'Dr.'),
  capt('capt', 'Capt.'),
  prof('prof', 'Prof.');

  const AttendeeTitle(this.value, this.label);
  final String value;
  final String label;

  static AttendeeTitle fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => AttendeeTitle.mr);
}

// ── Model ─────────────────────────────────────────────────────────────────

@immutable
class AttendeeModel {
  const AttendeeModel({
    required this.attendeeId,
    required this.caseId,
    required this.fullName,
    this.attendanceId,
    this.title,
    this.rankPosition,
    this.company,
    this.representing,
    this.roleType,
    this.dpCertification,
    this.certExpiry,
    this.contactEmail,
    this.contactPhone,
    this.createdAt,
  });

  final String attendeeId;
  final String caseId;
  final String fullName;
  final String? attendanceId;
  final AttendeeTitle? title;
  final String? rankPosition;
  final String? company;
  final String? representing;
  final AttendeeRole? roleType;
  final String? dpCertification;
  final DateTime? certExpiry;
  final String? contactEmail;
  final String? contactPhone;
  final DateTime? createdAt;

  /// Label used in the report attendees table
  String get reportLabel {
    final parts = <String>[];
    if (rankPosition != null) parts.add(rankPosition!);
    parts.add(fullName);
    return parts.join(' ');
  }

  /// Prefix for report (Mr./Capt./Dr. etc.) — falls back to a role-based
  /// guess when the surveyor hasn't picked a title explicitly.
  String get prefix {
    if (title != null) return title!.label;
    final role = roleType;
    if (role == AttendeeRole.master || role == AttendeeRole.portCaptain) {
      return 'Capt.';
    }
    return 'Mr./Ms.';
  }

  factory AttendeeModel.fromJson(Map<String, dynamic> j) => AttendeeModel(
        attendeeId:     j['attendee_id'] as String,
        caseId:         j['case_id'] as String,
        fullName:       j['full_name'] as String,
        attendanceId:   j['attendance_id'] as String?,
        title:          j['title'] != null
            ? AttendeeTitle.fromValue(j['title'] as String)
            : null,
        rankPosition:   j['rank_position'] as String?,
        company:        j['company'] as String?,
        representing:   j['representing'] as String?,
        roleType:       j['role_type'] != null
            ? AttendeeRole.fromValue(j['role_type'] as String)
            : null,
        dpCertification: j['dp_certification'] as String?,
        certExpiry:     j['cert_expiry'] != null
            ? DateTime.tryParse(j['cert_expiry'] as String)
            : null,
        contactEmail:   j['contact_email'] as String?,
        contactPhone:   j['contact_phone'] as String?,
        createdAt:      j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':   caseId,
        'full_name': fullName,
        if (attendanceId != null)    'attendance_id':    attendanceId,
        if (title != null)           'title':            title!.value,
        if (rankPosition != null)    'rank_position':    rankPosition,
        if (company != null)         'company':          company,
        if (representing != null)    'representing':     representing,
        if (roleType != null)        'role_type':        roleType!.value,
        if (dpCertification != null) 'dp_certification': dpCertification,
        if (certExpiry != null)
          'cert_expiry': certExpiry!.toIso8601String().split('T').first,
        if (contactEmail != null)    'contact_email':    contactEmail,
        if (contactPhone != null)    'contact_phone':    contactPhone,
      };
}

// ── Provider ───────────────────────────────────────────────────────────────

final attendeesProvider =
    AsyncNotifierProviderFamily<AttendeesNotifier, List<AttendeeModel>, String>(
  AttendeesNotifier.new,
);

class AttendeesNotifier
    extends FamilyAsyncNotifier<List<AttendeeModel>, String> {
  @override
  Future<List<AttendeeModel>> build(String caseId) => _fetch(caseId);

  Future<List<AttendeeModel>> _fetch(String caseId) async {
    final data = await SupabaseService.client
        .from('attendees')
        .select()
        .eq('case_id', caseId)
        .order('created_at');
    return (data as List).map((e) => AttendeeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AttendeeModel> addAttendee(AttendeeModel attendee) async {
    final data = await SupabaseService.client
        .from('attendees')
        .insert(attendee.toInsertJson())
        .select()
        .single();

    final created = AttendeeModel.fromJson(data);
    final current = state.value ?? [];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> updateAttendee(AttendeeModel attendee) async {
    await SupabaseService.client
        .from('attendees')
        .update(attendee.toInsertJson())
        .eq('attendee_id', attendee.attendeeId);

    final current = state.value ?? [];
    state = AsyncData(current
        .map((a) => a.attendeeId == attendee.attendeeId ? attendee : a)
        .toList());
  }

  Future<void> deleteAttendee(String attendeeId) async {
    await SupabaseService.client
        .from('attendees')
        .delete()
        .eq('attendee_id', attendeeId);

    final current = state.value ?? [];
    state = AsyncData(
        current.where((a) => a.attendeeId != attendeeId).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}
