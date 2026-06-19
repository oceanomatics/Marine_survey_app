// lib/features/correspondence/models/correspondence_model.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';

enum CorrStatus {
  pending,
  processing,
  completed,
  failed;

  static CorrStatus fromValue(String v) => switch (v) {
        'processing' => processing,
        'completed'  => completed,
        'failed'     => failed,
        _            => pending,
      };

  String get value => name;

  String get label => switch (this) {
        pending    => 'Not extracted',
        processing => 'Processing…',
        completed  => 'Extracted',
        failed     => 'Failed',
      };
}

@immutable
class ExtractedParty {
  const ExtractedParty({
    required this.name,
    this.company,
    this.role,
  });

  final String name;
  final String? company;
  final String? role;

  factory ExtractedParty.fromMap(Map<String, dynamic> m) => ExtractedParty(
        name:    m['name'] as String? ?? '',
        company: m['company'] as String?,
        role:    m['role'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        if (company != null) 'company': company,
        if (role != null) 'role': role,
      };
}

@immutable
class CorrespondenceModel {
  const CorrespondenceModel({
    required this.id,
    required this.caseId,
    required this.title,
    this.sender,
    this.recipient,
    this.corrDate,
    required this.localPath,
    this.summary,
    this.parties = const [],
    this.actions = const [],
    this.keyDates = const [],
    this.status = CorrStatus.pending,
    this.fileSizeKb,
    required this.createdAt,
  });

  final String id;
  final String caseId;
  final String title;
  final String? sender;
  final String? recipient;
  final DateTime? corrDate;
  final String localPath;
  final String? summary;
  final List<ExtractedParty> parties;
  final List<String> actions;
  final List<String> keyDates;
  final CorrStatus status;
  final double? fileSizeKb;
  final DateTime createdAt;

  factory CorrespondenceModel.fromMap(Map<String, dynamic> m) {
    List<ExtractedParty> parseParties(String? json) {
      if (json == null || json.isEmpty) return [];
      try {
        final list = jsonDecode(json) as List;
        return list
            .map((e) => ExtractedParty.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    List<String> parseStrings(String? json) {
      if (json == null || json.isEmpty) return [];
      try {
        return (jsonDecode(json) as List).cast<String>();
      } catch (_) {
        return [];
      }
    }

    return CorrespondenceModel(
      id:          m['id'] as String,
      caseId:      m['case_id'] as String,
      title:       m['title'] as String,
      sender:      m['sender'] as String?,
      recipient:   m['recipient'] as String?,
      corrDate:    m['corr_date'] != null
          ? DateTime.tryParse(m['corr_date'] as String)
          : null,
      localPath:   m['local_path'] as String,
      summary:     m['summary'] as String?,
      parties:     parseParties(m['parties_json'] as String?),
      actions:     parseStrings(m['actions_json'] as String?),
      keyDates:    parseStrings(m['key_dates_json'] as String?),
      status:      CorrStatus.fromValue(m['status'] as String? ?? 'pending'),
      fileSizeKb:  (m['file_size_kb'] as num?)?.toDouble(),
      createdAt:   DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id':             id,
        'case_id':        caseId,
        'title':          title,
        if (sender != null)    'sender':    sender,
        if (recipient != null) 'recipient': recipient,
        if (corrDate != null)  'corr_date': corrDate!.toIso8601String().split('T').first,
        'local_path':     localPath,
        if (summary != null)   'summary':   summary,
        'parties_json':   jsonEncode(parties.map((p) => p.toMap()).toList()),
        'actions_json':   jsonEncode(actions),
        'key_dates_json': jsonEncode(keyDates),
        'status':         status.value,
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
        'created_at':     createdAt.toIso8601String(),
      };

  CorrespondenceModel copyWith({
    String? title,
    String? sender,
    String? recipient,
    DateTime? corrDate,
    String? summary,
    List<ExtractedParty>? parties,
    List<String>? actions,
    List<String>? keyDates,
    CorrStatus? status,
  }) =>
      CorrespondenceModel(
        id:          id,
        caseId:      caseId,
        title:       title ?? this.title,
        sender:      sender ?? this.sender,
        recipient:   recipient ?? this.recipient,
        corrDate:    corrDate ?? this.corrDate,
        localPath:   localPath,
        summary:     summary ?? this.summary,
        parties:     parties ?? this.parties,
        actions:     actions ?? this.actions,
        keyDates:    keyDates ?? this.keyDates,
        status:      status ?? this.status,
        fileSizeKb:  fileSizeKb,
        createdAt:   createdAt,
      );
}
