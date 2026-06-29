// lib/features/surveyor_notes/models/surveyor_note_model.dart

import 'package:flutter/foundation.dart';

// ── Cue priority ──────────────────────────────────────────────────────────

enum CuePriority {
  important,
  normal,
  ignored;

  static CuePriority fromValue(String? v) => switch (v) {
        'important' => important,
        'ignored'   => ignored,
        _           => normal,
      };

  String get value => name;

  String get label => switch (this) {
        important => 'Important',
        normal    => 'Normal',
        ignored   => 'Ignored',
      };
}

// ── Note category (type of observation) ──────────────────────────────────

enum NoteCategory {
  observation,
  measurement,
  followUp,
  interview,
  technical,
  operations,
  previousWorks,
  policy,
  invoicing,
  general;

  static NoteCategory fromValue(String v) => switch (v) {
        'observation'    => observation,
        'measurement'    => measurement,
        'follow_up'      => followUp,
        'interview'      => interview,
        'technical'      => technical,
        'operations'     => operations,
        'previous_works' => previousWorks,
        'policy'         => policy,
        'invoicing'      => invoicing,
        _                => general,
      };

  String get value => switch (this) {
        followUp      => 'follow_up',
        previousWorks => 'previous_works',
        _             => name,
      };

  String get label => switch (this) {
        observation   => 'Observation',
        measurement   => 'Measurement',
        followUp      => 'Follow-up',
        interview     => 'Interview',
        technical     => 'Technical',
        operations    => 'Operations',
        previousWorks => 'Prev. Works',
        policy        => 'Policy',
        invoicing     => 'Invoicing',
        general       => 'General',
      };
}

// ── Report section tag ────────────────────────────────────────────────────
//
// Each section matches a section of the survey report.
// Notes tagged with a section surface in the corresponding report builder
// section and in the section's own screen.

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

  String get shortLabel => switch (this) {
        background      => 'Background',
        occurrence      => 'Occurrence',
        attendance      => 'Attendance',
        timeline        => 'Timeline',
        causation       => 'Causation',
        damage          => 'Damage',
        repairs         => 'Repairs',
        repairTimes     => 'Repair Times',
        extraExpenses   => 'Extra Expenses',
        generalExpenses => 'Gen. Expenses',
        notAverage      => 'Not Average',
        otherMatters    => 'Other Matters',
      };

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
    this.priority = CuePriority.normal,
    this.resolvedAt,
    this.linkedToType,
    this.linkedToId,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String caseId;
  final String content;
  final NoteCategory category;
  final ReportSection? reportSection;
  final CuePriority priority;
  final DateTime? resolvedAt;
  final String? linkedToType;
  final String? linkedToId;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isResolved => resolvedAt != null;

  factory SurveyorNote.fromMap(Map<String, dynamic> m) => SurveyorNote(
        id:            m['id'] as String,
        caseId:        m['case_id'] as String,
        content:       m['content'] as String,
        category:      NoteCategory.fromValue(m['category'] as String? ?? 'general'),
        reportSection: ReportSection.fromValue(m['report_section'] as String?),
        priority:      CuePriority.fromValue(m['priority'] as String?),
        resolvedAt:    m['resolved_at'] != null
            ? DateTime.tryParse(m['resolved_at'] as String)
            : null,
        linkedToType:  m['linked_to_type'] as String?,
        linkedToId:    m['linked_to_id'] as String?,
        source:        m['source'] as String?,
        createdAt:     DateTime.parse(m['created_at'] as String),
        updatedAt:     DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'case_id':         caseId,
        'content':         content,
        'category':        category.value,
        'report_section':  reportSection?.value,
        'priority':        priority.value,
        'resolved_at':     resolvedAt?.toIso8601String(),
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null)   'linked_to_id':   linkedToId,
        if (source != null)       'source':          source,
        'created_at':      createdAt.toIso8601String(),
        'updated_at':      updatedAt.toIso8601String(),
      };

  SurveyorNote copyWith({
    String? content,
    NoteCategory? category,
    Object? reportSection = _sentinel,
    CuePriority? priority,
    Object? resolvedAt = _sentinel,
    String? linkedToType,
    String? linkedToId,
    String? source,
  }) =>
      SurveyorNote(
        id:            id,
        caseId:        caseId,
        content:       content ?? this.content,
        category:      category ?? this.category,
        reportSection: reportSection == _sentinel
            ? this.reportSection
            : reportSection as ReportSection?,
        priority:      priority ?? this.priority,
        resolvedAt:    resolvedAt == _sentinel
            ? this.resolvedAt
            : resolvedAt as DateTime?,
        linkedToType:  linkedToType ?? this.linkedToType,
        linkedToId:    linkedToId ?? this.linkedToId,
        source:        source ?? this.source,
        createdAt:     createdAt,
        updatedAt:     DateTime.now(),
      );
}

const Object _sentinel = Object();
