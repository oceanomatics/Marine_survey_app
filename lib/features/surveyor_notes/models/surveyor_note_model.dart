// lib/features/surveyor_notes/models/surveyor_note_model.dart

import 'package:flutter/foundation.dart';

// ── Note category (type of observation) ──────────────────────────────────

enum NoteCategory {
  observation,
  measurement,
  followUp,
  interview,
  technical,
  general;

  static NoteCategory fromValue(String v) => switch (v) {
        'observation'  => observation,
        'measurement'  => measurement,
        'follow_up'    => followUp,
        'interview'    => interview,
        'technical'    => technical,
        _              => general,
      };

  String get value => switch (this) {
        followUp => 'follow_up',
        _        => name,
      };

  String get label => switch (this) {
        observation => 'Observation',
        measurement => 'Measurement',
        followUp    => 'Follow-up',
        interview   => 'Interview',
        technical   => 'Technical',
        general     => 'General',
      };
}

// ── Report section tag ────────────────────────────────────────────────────
//
// Each section matches a section of the survey report (and the pseudo-report
// on the case home screen).  Notes tagged with a section are surfaced in the
// corresponding report builder section and in the section's own screen.

enum ReportSection {
  background,
  occurrence,
  attendance,
  timeline,
  causation,
  damage,
  repairs,
  repairTimes,
  extraExpenses,
  generalExpenses,
  notAverage,
  otherMatters;

  static ReportSection? fromValue(String? v) {
    if (v == null) return null;
    return switch (v) {
      'background'       => background,
      'occurrence'       => occurrence,
      'attendance'       => attendance,
      'timeline'         => timeline,
      'causation'        => causation,
      'damage'           => damage,
      'repairs'          => repairs,
      'repair_times'     => repairTimes,
      'extra_expenses'   => extraExpenses,
      'general_expenses' => generalExpenses,
      'not_average'      => notAverage,
      'other_matters'    => otherMatters,
      _                  => null,
    };
  }

  String get value => switch (this) {
        repairTimes     => 'repair_times',
        extraExpenses   => 'extra_expenses',
        generalExpenses => 'general_expenses',
        notAverage      => 'not_average',
        otherMatters    => 'other_matters',
        _               => name,
      };

  String get label => switch (this) {
        background      => 'Background',
        occurrence      => 'Occurrence',
        attendance      => 'Attendance & Representatives',
        timeline        => 'Case Timeline',
        causation       => 'Allegation / Causation',
        damage          => 'Extent of Damage',
        repairs         => 'Repairs',
        repairTimes     => 'Repair Times',
        extraExpenses   => 'Extra Expenses',
        generalExpenses => 'General Expenses',
        notAverage      => 'Work Not Concerning Average',
        otherMatters    => 'Other Matters of Relevance',
      };

  // Report order for display / grouping
  static const ordered = [
    background,
    occurrence,
    attendance,
    timeline,
    causation,
    damage,
    repairs,
    repairTimes,
    extraExpenses,
    generalExpenses,
    notAverage,
    otherMatters,
  ];
}

// ── SurveyorNote model ────────────────────────────────────────────────────

@immutable
class SurveyorNote {
  const SurveyorNote({
    required this.id,
    required this.caseId,
    required this.content,
    this.category = NoteCategory.general,
    this.reportSection,
    this.linkedToType,
    this.linkedToId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String caseId;
  final String content;
  final NoteCategory category;
  final ReportSection? reportSection;
  final String? linkedToType;
  final String? linkedToId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SurveyorNote.fromMap(Map<String, dynamic> m) => SurveyorNote(
        id:            m['id'] as String,
        caseId:        m['case_id'] as String,
        content:       m['content'] as String,
        category:      NoteCategory.fromValue(m['category'] as String? ?? 'general'),
        reportSection: ReportSection.fromValue(m['report_section'] as String?),
        linkedToType:  m['linked_to_type'] as String?,
        linkedToId:    m['linked_to_id'] as String?,
        createdAt:     DateTime.parse(m['created_at'] as String),
        updatedAt:     DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'case_id':         caseId,
        'content':         content,
        'category':        category.value,
        'report_section':  reportSection?.value,
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null)   'linked_to_id':   linkedToId,
        'created_at':      createdAt.toIso8601String(),
        'updated_at':      updatedAt.toIso8601String(),
      };

  SurveyorNote copyWith({
    String? content,
    NoteCategory? category,
    Object? reportSection = _sentinel,
    String? linkedToType,
    String? linkedToId,
  }) =>
      SurveyorNote(
        id:            id,
        caseId:        caseId,
        content:       content ?? this.content,
        category:      category ?? this.category,
        reportSection: reportSection == _sentinel
            ? this.reportSection
            : reportSection as ReportSection?,
        linkedToType:  linkedToType ?? this.linkedToType,
        linkedToId:    linkedToId ?? this.linkedToId,
        createdAt:     createdAt,
        updatedAt:     DateTime.now(),
      );
}

// Sentinel to distinguish "pass null explicitly" from "omit the argument"
const Object _sentinel = Object();
