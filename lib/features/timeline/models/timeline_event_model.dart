// lib/features/timeline/models/timeline_event_model.dart

import 'package:flutter/foundation.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum TimelineEventType {
  vesselDeparture('vessel_departure', 'Vessel Departure'),
  vesselArrival('vessel_arrival', 'Vessel Arrived in Port'),
  drydockEntry('drydock_entry', 'Drydock Entry'),
  drydockExit('drydock_exit', 'Drydock Exit / Undocked'),
  tempRepairStart('temp_repair_start', 'Temporary Repairs Commenced'),
  tempRepairComplete('temp_repair_complete', 'Temporary Repairs Completed'),
  permRepairStart('perm_repair_start', 'Permanent Repairs Commenced'),
  permRepairComplete('perm_repair_complete', 'Permanent Repairs Completed'),
  surveyorRemark('surveyor_remark', 'Surveyor Remark'),
  custom('custom', 'Custom Event');

  const TimelineEventType(this.value, this.label);
  final String value;
  final String label;

  static TimelineEventType fromValue(String v) =>
      values.firstWhere((e) => e.value == v,
          orElse: () => TimelineEventType.custom);
}

// ── Model ──────────────────────────────────────────────────────────────────

@immutable
class TimelineEventModel {
  const TimelineEventModel({
    required this.eventId,
    required this.caseId,
    required this.eventType,
    this.eventDate,
    this.title,
    this.location,
    this.description,
    this.sourceKey,
    this.createdAt,
  });

  final String eventId;
  final String caseId;
  final TimelineEventType eventType;
  final DateTime? eventDate;
  final String? title;
  final String? location;
  final String? description;
  /// When this row was promoted into the chronology from an aggregated Full
  /// Event Log entry (occurrence/attendance/repair), the origin event's stable
  /// key ("<source>:<source_id>"). NULL for manually-typed timeline events.
  /// See TODO.md §3.16 and timeline_entry.dart.
  final String? sourceKey;
  final DateTime? createdAt;

  factory TimelineEventModel.fromJson(Map<String, dynamic> j) =>
      TimelineEventModel(
        eventId:     j['event_id'] as String,
        caseId:      j['case_id'] as String,
        eventType:   TimelineEventType.fromValue(
            j['event_type'] as String? ?? 'custom'),
        eventDate:   j['event_date'] != null
            ? DateTime.tryParse(j['event_date'] as String)
            : null,
        title:       j['title'] as String?,
        location:    j['location'] as String?,
        description: j['description'] as String?,
        sourceKey:   j['source_key'] as String?,
        createdAt:   j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'case_id':    caseId,
        'event_type': eventType.value,
        if (eventDate != null)
          'event_date': _fmtDate(eventDate!),
        if (title != null && title!.isNotEmpty)       'title':       title,
        if (location != null && location!.isNotEmpty) 'location':    location,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (sourceKey != null && sourceKey!.isNotEmpty) 'source_key': sourceKey,
      };

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
