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

// ── Nature of content (what kind of information the cue is) ──────────────

enum NatureOfContent {
  observationFinding,
  recommendation,
  followUpOpenQuestion,
  backgroundReference;

  static NatureOfContent? fromValue(String? v) => switch (v) {
        'observation_finding'     => observationFinding,
        'recommendation'          => recommendation,
        'follow_up_open_question' => followUpOpenQuestion,
        'background_reference'    => backgroundReference,
        _                         => null,
      };

  String get value => switch (this) {
        observationFinding   => 'observation_finding',
        recommendation        => 'recommendation',
        followUpOpenQuestion  => 'follow_up_open_question',
        backgroundReference   => 'background_reference',
      };

  String get label => switch (this) {
        observationFinding   => 'Observation / Finding',
        recommendation        => 'Recommendation',
        followUpOpenQuestion  => 'Follow-up / Open Question',
        backgroundReference   => 'Background / Reference',
      };
}

// ── Evidentiary weight (how much weight the content carries) ─────────────

enum EvidentiaryWeight {
  fact,
  opinion,
  allegation,
  hearsay;

  static EvidentiaryWeight? fromValue(String? v) => switch (v) {
        'fact'      => fact,
        'opinion'   => opinion,
        'allegation'=> allegation,
        'hearsay'   => hearsay,
        _           => null,
      };

  String get value => name;

  String get label => switch (this) {
        fact       => 'Fact',
        opinion    => 'Opinion',
        allegation => 'Allegation',
        hearsay    => 'Hearsay',
      };
}

// ── Origin (who the cue's content comes from) ─────────────────────────────

enum CueOrigin {
  assuredOwner,
  thirdParty,
  surveyor;

  static CueOrigin? fromValue(String? v) => switch (v) {
        'assured_owner' => assuredOwner,
        'third_party'   => thirdParty,
        'surveyor'      => surveyor,
        _               => null,
      };

  String get value => switch (this) {
        assuredOwner => 'assured_owner',
        thirdParty   => 'third_party',
        surveyor     => 'surveyor',
      };

  String get label => switch (this) {
        assuredOwner => 'Assured / Owner',
        thirdParty   => 'Third Party',
        surveyor     => 'Surveyor',
      };
}

// ── Case section tag ───────────────────────────────────────────────────────
//
// Allocates a cue to a case-screen section. Renamed from `ReportSection`
// (docs/context_cue_system_review.md §3.4) — of these 14 values, only 5 are
// ever read by the report builder to produce report content; the rest just
// allocate a cue to where it belongs on the case screen. A cue tagged with a
// section surfaces in that section's own screen and, for the sections that
// are wired up, in the corresponding report builder section.

enum CaseSection {
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
  previousWorks,
  contractualHire;

  static CaseSection? fromValue(String? v) {
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
      'previous_works'   => previousWorks,
      'contractual_hire' => contractualHire,
      _                  => null,
    };
  }

  String get value => switch (this) {
        repairTimes     => 'repair_times',
        extraExpenses   => 'extra_expenses',
        generalExpenses => 'general_expenses',
        notAverage      => 'not_average',
        otherMatters    => 'other_matters',
        previousWorks   => 'previous_works',
        contractualHire => 'contractual_hire',
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
        previousWorks   => 'Previous Work on the Damaged Item',
        contractualHire => 'Contractual / Hire',
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
        previousWorks   => 'Previous Works',
        contractualHire => 'Contractual/Hire',
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
    previousWorks,
    contractualHire,
  ];

  /// True for case sections whose cues are meaningfully scoped to a specific
  /// repair period rather than the case as a whole (docs/context_cue_system_
  /// review.md §3.1/§3.2) — Work Not Concerning Average and General
  /// Services & Access both belong to whichever repair period they occur
  /// in. A cue in one of these sections may still have no period link
  /// (shown as "not allocated to a period" rather than being blocked).
  bool get isRepairPeriodScoped =>
      this == notAverage || this == generalExpenses;
}

// ── SurveyorNote model ────────────────────────────────────────────────────

@immutable
class SurveyorNote {
  const SurveyorNote({
    required this.id,
    required this.caseId,
    required this.content,
    this.natureOfContent,
    this.evidentiaryWeight,
    this.origin,
    this.caseSection,
    this.priority = CuePriority.normal,
    this.lostRelevanceAt,
    this.linkedToType,
    this.linkedToId,
    this.source,
    this.pendingReview = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String caseId;
  final String content;
  final NatureOfContent? natureOfContent;
  final EvidentiaryWeight? evidentiaryWeight;
  final CueOrigin? origin;
  final CaseSection? caseSection;
  final CuePriority priority;
  /// When this cue stopped being relevant — auto-set when [priority] is set
  /// to [CuePriority.ignored] (docs/context_cue_system_review.md §3.6),
  /// rather than a separately-toggled state.
  final DateTime? lostRelevanceAt;
  final String? linkedToType;
  final String? linkedToId;
  final String? source;
  /// True when [caseSection]/[origin] are an unconfirmed AI suggestion from
  /// document extraction (docs/context_cue_system_review.md §3.5) — shown
  /// in the Context Cue Manager's "Suggested" tab and excluded from feeding
  /// any AI-drafted report section until a human reviews and saves it.
  final bool pendingReview;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasLostRelevance => lostRelevanceAt != null;

  factory SurveyorNote.fromMap(Map<String, dynamic> m) => SurveyorNote(
        id:                m['id'] as String,
        caseId:            m['case_id'] as String,
        content:           m['content'] as String,
        natureOfContent:   NatureOfContent.fromValue(m['nature_of_content'] as String?),
        evidentiaryWeight: EvidentiaryWeight.fromValue(m['evidentiary_weight'] as String?),
        origin:            CueOrigin.fromValue(m['origin'] as String?),
        caseSection:       CaseSection.fromValue(m['case_section'] as String?),
        priority:          CuePriority.fromValue(m['priority'] as String?),
        lostRelevanceAt:   m['lost_relevance_at'] != null
            ? DateTime.tryParse(m['lost_relevance_at'] as String)
            : null,
        linkedToType:      m['linked_to_type'] as String?,
        linkedToId:        m['linked_to_id'] as String?,
        source:            m['source'] as String?,
        pendingReview:     m['pending_review'] == true || m['pending_review'] == 1,
        createdAt:         DateTime.parse(m['created_at'] as String),
        updatedAt:         DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':                 id,
        'case_id':            caseId,
        'content':            content,
        'nature_of_content':  natureOfContent?.value,
        'evidentiary_weight': evidentiaryWeight?.value,
        'origin':             origin?.value,
        'case_section':       caseSection?.value,
        'priority':           priority.value,
        'lost_relevance_at':  lostRelevanceAt?.toIso8601String(),
        if (linkedToType != null) 'linked_to_type': linkedToType,
        if (linkedToId != null)   'linked_to_id':   linkedToId,
        if (source != null)       'source':          source,
        'pending_review':     pendingReview,
        'created_at':         createdAt.toIso8601String(),
        'updated_at':         updatedAt.toIso8601String(),
      };

  SurveyorNote copyWith({
    String? content,
    Object? natureOfContent = _sentinel,
    Object? evidentiaryWeight = _sentinel,
    Object? origin = _sentinel,
    Object? caseSection = _sentinel,
    CuePriority? priority,
    Object? lostRelevanceAt = _sentinel,
    String? linkedToType,
    String? linkedToId,
    String? source,
    bool? pendingReview,
  }) =>
      SurveyorNote(
        id:            id,
        caseId:        caseId,
        content:       content ?? this.content,
        natureOfContent: natureOfContent == _sentinel
            ? this.natureOfContent
            : natureOfContent as NatureOfContent?,
        evidentiaryWeight: evidentiaryWeight == _sentinel
            ? this.evidentiaryWeight
            : evidentiaryWeight as EvidentiaryWeight?,
        origin: origin == _sentinel ? this.origin : origin as CueOrigin?,
        caseSection: caseSection == _sentinel
            ? this.caseSection
            : caseSection as CaseSection?,
        priority:      priority ?? this.priority,
        lostRelevanceAt: lostRelevanceAt == _sentinel
            ? this.lostRelevanceAt
            : lostRelevanceAt as DateTime?,
        linkedToType:  linkedToType ?? this.linkedToType,
        linkedToId:    linkedToId ?? this.linkedToId,
        source:        source ?? this.source,
        pendingReview: pendingReview ?? this.pendingReview,
        createdAt:     createdAt,
        updatedAt:     DateTime.now(),
      );
}

const Object _sentinel = Object();
