// lib/features/surveyor_notes/models/surveyor_note_model.dart

import 'package:flutter/foundation.dart';

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

@immutable
class SurveyorNote {
  const SurveyorNote({
    required this.id,
    required this.caseId,
    required this.content,
    this.category = NoteCategory.general,
    this.linkedToType,
    this.linkedToId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String caseId;
  final String content;
  final NoteCategory category;
  final String? linkedToType;
  final String? linkedToId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SurveyorNote.fromMap(Map<String, dynamic> m) => SurveyorNote(
        id:           m['id'] as String,
        caseId:       m['case_id'] as String,
        content:      m['content'] as String,
        category:     NoteCategory.fromValue(m['category'] as String? ?? 'general'),
        linkedToType: m['linked_to_type'] as String?,
        linkedToId:   m['linked_to_id'] as String?,
        createdAt:    DateTime.parse(m['created_at'] as String),
        updatedAt:    DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'case_id':         caseId,
        'content':         content,
        'category':        category.value,
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null)   'linked_to_id':   linkedToId,
        'created_at':      createdAt.toIso8601String(),
        'updated_at':      updatedAt.toIso8601String(),
      };

  SurveyorNote copyWith({
    String? content,
    NoteCategory? category,
    String? linkedToType,
    String? linkedToId,
  }) =>
      SurveyorNote(
        id:           id,
        caseId:       caseId,
        content:      content ?? this.content,
        category:     category ?? this.category,
        linkedToType: linkedToType ?? this.linkedToType,
        linkedToId:   linkedToId ?? this.linkedToId,
        createdAt:    createdAt,
        updatedAt:    DateTime.now(),
      );
}
