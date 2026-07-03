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
    this.sortOrder,
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
  /// Manual drag-to-reorder position within an attendance (TODO.md §3.1).
  /// Nulls sort last — only possible for rows created before migration 015.
  final int? sortOrder;

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
        sortOrder:      j['sort_order'] as int?,
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
        if (sortOrder != null)       'sort_order':        sortOrder,
      };

  AttendeeModel copyWith({int? sortOrder}) => AttendeeModel(
        attendeeId:      attendeeId,
        caseId:          caseId,
        fullName:        fullName,
        attendanceId:    attendanceId,
        title:           title,
        rankPosition:    rankPosition,
        company:         company,
        representing:    representing,
        roleType:        roleType,
        dpCertification: dpCertification,
        certExpiry:      certExpiry,
        contactEmail:    contactEmail,
        contactPhone:    contactPhone,
        createdAt:       createdAt,
        sortOrder:       sortOrder ?? this.sortOrder,
      );
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
        .order('sort_order', nullsFirst: false)
        .order('created_at');
    return (data as List).map((e) => AttendeeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AttendeeModel> addAttendee(AttendeeModel attendee) async {
    // New attendees append at the end of their attendance's order
    // (TODO.md §3.1 "Default order: insertion order").
    final current = state.value ?? [];
    final siblingMax = current
        .where((a) => a.attendanceId == attendee.attendanceId)
        .map((a) => a.sortOrder ?? 0)
        .fold(0, (m, v) => v > m ? v : m);

    final data = await SupabaseService.client
        .from('attendees')
        .insert(attendee.copyWith(sortOrder: siblingMax + 1).toInsertJson())
        .select()
        .single();

    final created = AttendeeModel.fromJson(data);
    state = AsyncData([...current, created]);
    return created;
  }

  /// Persists a manual drag-to-reorder within one attendance — [orderedIds]
  /// is the full new attendee-id order for that attendance.
  Future<void> reorderAttendees(List<String> orderedIds) async {
    final current = state.value ?? [];
    final byId = {for (final a in current) a.attendeeId: a};
    final updated = <AttendeeModel>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final a = byId[orderedIds[i]];
      if (a == null) continue;
      updated.add(a.copyWith(sortOrder: i + 1));
    }

    state = AsyncData(current
        .map((a) => updated.firstWhere(
            (u) => u.attendeeId == a.attendeeId,
            orElse: () => a))
        .toList());

    await Future.wait(updated.map((a) => SupabaseService.client
        .from('attendees')
        .update({'sort_order': a.sortOrder})
        .eq('attendee_id', a.attendeeId)));
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
