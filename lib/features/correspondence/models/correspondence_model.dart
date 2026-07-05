// lib/features/correspondence/models/correspondence_model.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// References extracted from a correspondence by the AI that can be applied
/// to the parent case (job number, claim ref, vessel name, instruction date).
@immutable
class ExtractedCaseRefs {
  const ExtractedCaseRefs({
    this.technicalFileNo,
    this.claimReference,
    this.vesselName,
    this.instructionDate,
  });

  final String? technicalFileNo;
  final String? claimReference;
  final String? vesselName;
  final DateTime? instructionDate;

  bool get hasAny =>
      technicalFileNo != null ||
      claimReference != null ||
      vesselName != null ||
      instructionDate != null;
}

enum CorrStatus {
  pending,
  processing,
  completed,
  failed;

  static CorrStatus fromValue(String v) => switch (v) {
        'processing' => processing,
        'completed' => completed,
        'failed' => failed,
        _ => pending,
      };

  String get value => name;

  String get label => switch (this) {
        pending => 'Not extracted',
        processing => 'Processing…',
        completed => 'Extracted',
        failed => 'Failed',
      };
}

@immutable
class ExtractedParty {
  const ExtractedParty({
    required this.name,
    this.company,
    this.role,
    this.email,
    this.phone,
  });

  final String name;
  final String? company;
  final String? role;
  final String? email;
  final String? phone;

  factory ExtractedParty.fromMap(Map<String, dynamic> m) => ExtractedParty(
        name: m['name'] as String? ?? '',
        company: m['company'] as String?,
        role: m['role'] as String?,
        email: m['email'] as String?,
        phone: m['phone'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        if (company != null) 'company': company,
        if (role != null) 'role': role,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
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
    this.localPath,
    this.fileType = 'pdf',
    this.summary,
    this.bodyText,
    this.parties = const [],
    this.actions = const [],
    this.keyDates = const [],
    this.status = CorrStatus.pending,
    this.fileSizeKb,
    this.driveFileId,
    required this.createdAt,
  });

  final String id;
  final String caseId;
  final String title;
  final String? sender;
  final String? recipient;
  final DateTime? corrDate;

  /// Per-device local cache path — null if not yet downloaded/cached on
  /// this device (synced from another device, or viewed on web).
  final String? localPath;

  /// 'eml' | 'pdf' — was derived from [localPath]'s extension, but that's
  /// no longer reliable now [localPath] can be null (unified storage).
  final String fileType;
  final String? summary;
  final String? bodyText;
  final List<ExtractedParty> parties;
  final List<String> actions;
  final List<String> keyDates;
  final CorrStatus status;
  final double? fileSizeKb;

  /// Drive file id of the canonical, cross-platform copy (unified storage).
  final String? driveFileId;
  final DateTime createdAt;

  bool get isEml => fileType == 'eml';
  bool get hasLocalFile => localPath != null && localPath!.isNotEmpty;

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
      id: m['id'] as String,
      caseId: m['case_id'] as String,
      title: m['title'] as String,
      sender: m['sender'] as String?,
      recipient: m['recipient'] as String?,
      corrDate: m['corr_date'] != null
          ? DateTime.tryParse(m['corr_date'] as String)
          : null,
      localPath: (m['local_path'] as String?)?.isEmpty == true
          ? null
          : m['local_path'] as String?,
      fileType: m['file_type'] as String? ?? 'pdf',
      summary: m['summary'] as String?,
      bodyText: m['body_text'] as String?,
      parties: parseParties(m['parties_json'] as String?),
      actions: parseStrings(m['actions_json'] as String?),
      keyDates: parseStrings(m['key_dates_json'] as String?),
      status: CorrStatus.fromValue(m['status'] as String? ?? 'pending'),
      fileSizeKb: (m['file_size_kb'] as num?)?.toDouble(),
      driveFileId: m['drive_file_id'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  /// Parses a row from Supabase (canonical metadata; no local_path).
  factory CorrespondenceModel.fromSupabaseMap(Map<String, dynamic> m) {
    List<ExtractedParty> parseParties(dynamic v) {
      if (v == null) return [];
      final list = v is String ? jsonDecode(v) as List : v as List;
      return list
          .map((e) => ExtractedParty.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    List<String> parseStrings(dynamic v) {
      if (v == null) return [];
      final list = v is String ? jsonDecode(v) as List : v as List;
      return list.cast<String>();
    }

    return CorrespondenceModel(
      id: m['id'] as String,
      caseId: m['case_id'] as String,
      title: m['title'] as String,
      sender: m['sender'] as String?,
      recipient: m['recipient'] as String?,
      corrDate: m['corr_date'] != null
          ? DateTime.tryParse(m['corr_date'] as String)
          : null,
      fileType: m['file_type'] as String? ?? 'pdf',
      summary: m['summary'] as String?,
      bodyText: m['body_text'] as String?,
      parties: parseParties(m['parties_json']),
      actions: parseStrings(m['actions_json']),
      keyDates: parseStrings(m['key_dates_json']),
      status: CorrStatus.fromValue(m['status'] as String? ?? 'pending'),
      fileSizeKb: (m['file_size_kb'] as num?)?.toDouble(),
      driveFileId: m['drive_file_id'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    );
  }

  /// Serializes for the local SQLite cache — includes local_path.
  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'title': title,
        if (sender != null) 'sender': sender,
        if (recipient != null) 'recipient': recipient,
        if (corrDate != null)
          'corr_date': corrDate!.toIso8601String().split('T').first,
        'local_path': localPath ?? '',
        'file_type': fileType,
        if (summary != null) 'summary': summary,
        if (bodyText != null) 'body_text': bodyText,
        'parties_json': jsonEncode(parties.map((p) => p.toMap()).toList()),
        'actions_json': jsonEncode(actions),
        'key_dates_json': jsonEncode(keyDates),
        'status': status.value,
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
        if (driveFileId != null) 'drive_file_id': driveFileId,
        'created_at': createdAt.toIso8601String(),
      };

  /// Serializes for the Supabase `correspondence` table — canonical
  /// metadata only, no per-device local_path.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'case_id': caseId,
        'title': title,
        if (sender != null) 'sender': sender,
        if (recipient != null) 'recipient': recipient,
        if (corrDate != null)
          'corr_date': corrDate!.toIso8601String().split('T').first,
        'file_type': fileType,
        if (summary != null) 'summary': summary,
        if (bodyText != null) 'body_text': bodyText,
        'parties_json': jsonEncode(parties.map((p) => p.toMap()).toList()),
        'actions_json': jsonEncode(actions),
        'key_dates_json': jsonEncode(keyDates),
        'status': status.value,
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
        if (driveFileId != null) 'drive_file_id': driveFileId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  CorrespondenceModel copyWith({
    String? title,
    String? sender,
    String? recipient,
    DateTime? corrDate,
    String? summary,
    String? bodyText,
    List<ExtractedParty>? parties,
    List<String>? actions,
    List<String>? keyDates,
    CorrStatus? status,
    String? localPath,
    String? driveFileId,
  }) =>
      CorrespondenceModel(
        id: id,
        caseId: caseId,
        title: title ?? this.title,
        sender: sender ?? this.sender,
        recipient: recipient ?? this.recipient,
        corrDate: corrDate ?? this.corrDate,
        localPath: localPath ?? this.localPath,
        fileType: fileType,
        summary: summary ?? this.summary,
        bodyText: bodyText ?? this.bodyText,
        parties: parties ?? this.parties,
        actions: actions ?? this.actions,
        keyDates: keyDates ?? this.keyDates,
        status: status ?? this.status,
        fileSizeKb: fileSizeKb,
        driveFileId: driveFileId ?? this.driveFileId,
        createdAt: createdAt,
      );
}
