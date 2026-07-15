// lib/features/interviews/models/interview_model.dart

// ── Participant ────────────────────────────────────────────────────────────

class InterviewParticipant {
  const InterviewParticipant({
    required this.contactId,
    required this.fullName,
    this.roleTitle,
    this.company,
  });

  final String  contactId;
  final String  fullName;
  final String? roleTitle;
  final String? company;

  factory InterviewParticipant.fromJson(Map<String, dynamic> j) =>
      InterviewParticipant(
        contactId: j['contact_id'] as String,
        fullName:  j['full_name']  as String,
        roleTitle: j['role_title'] as String?,
        company:   j['company']   as String?,
      );

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'full_name':  fullName,
        if (roleTitle != null) 'role_title': roleTitle,
        if (company   != null) 'company':    company,
      };

  String get displayName => roleTitle != null ? '$fullName · $roleTitle' : fullName;
}

// ── Interview ──────────────────────────────────────────────────────────────

class InterviewModel {
  const InterviewModel({
    required this.interviewId,
    required this.caseId,
    required this.createdAt,
    required this.participants,
    required this.transcript,
    this.title,
    this.durationSecs,
    this.filedToVault,
    this.vaultDocId,
    this.summary,
    this.audioPath,
  });

  final String   interviewId;
  final String   caseId;
  final DateTime createdAt;
  final String?  title;
  final List<InterviewParticipant> participants;
  final String   transcript;
  final int?     durationSecs;
  final bool?    filedToVault;
  final String?  vaultDocId;
  final String?  summary;
  /// Path within the 'interview-audio' storage bucket to the raw recording
  /// (14 July 2026 walkthrough) — null for interviews recorded before this
  /// existed, or if nothing was captured.
  final String?  audioPath;

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    final names = participants.map((p) => p.fullName).join(', ');
    return names.isNotEmpty ? 'Interview: $names' : 'Interview';
  }

  factory InterviewModel.fromJson(Map<String, dynamic> j) {
    final rawParts = j['participants'];
    List<InterviewParticipant> parts = [];
    if (rawParts is List) {
      parts = rawParts
          .whereType<Map<String, dynamic>>()
          .map(InterviewParticipant.fromJson)
          .toList();
    }
    return InterviewModel(
      interviewId:  j['interview_id']  as String,
      caseId:       j['case_id']       as String,
      createdAt:    DateTime.parse(j['created_at'] as String),
      title:        j['title']         as String?,
      participants: parts,
      transcript:   (j['transcript']   as String?) ?? '',
      durationSecs: j['duration_secs'] as int?,
      filedToVault: j['filed_to_vault'] as bool?,
      vaultDocId:   j['vault_doc_id']  as String?,
      summary:      j['summary']       as String?,
      audioPath:    j['audio_path']    as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'interview_id':  interviewId,
        'case_id':       caseId,
        'participants':  participants.map((p) => p.toJson()).toList(),
        'transcript':    transcript,
        if (title        != null) 'title':          title,
        if (durationSecs != null) 'duration_secs':  durationSecs,
        if (filedToVault != null) 'filed_to_vault': filedToVault,
        if (vaultDocId   != null) 'vault_doc_id':   vaultDocId,
        if (summary      != null) 'summary':        summary,
        if (audioPath    != null) 'audio_path':     audioPath,
      };

  InterviewModel copyWith({
    String?  title,
    List<InterviewParticipant>? participants,
    String?  transcript,
    int?     durationSecs,
    bool?    filedToVault,
    String?  vaultDocId,
    String?  summary,
    String?  audioPath,
  }) =>
      InterviewModel(
        interviewId:  interviewId,
        caseId:       caseId,
        createdAt:    createdAt,
        title:        title        ?? this.title,
        participants: participants ?? this.participants,
        transcript:   transcript   ?? this.transcript,
        durationSecs: durationSecs ?? this.durationSecs,
        filedToVault: filedToVault ?? this.filedToVault,
        vaultDocId:   vaultDocId   ?? this.vaultDocId,
        summary:      summary      ?? this.summary,
        audioPath:    audioPath    ?? this.audioPath,
      );
}
