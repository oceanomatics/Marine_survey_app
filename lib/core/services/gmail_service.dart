// lib/core/services/gmail_service.dart
//
// Thin wrapper around the Gmail v1 REST API. Authentication is shared with
// Drive/Photos via GoogleAuthService (see that file for OAuth setup).
//
// Reading a message with format=raw returns the full RFC822 source
// (base64url-encoded) — exactly the byte shape of a .eml file, so it feeds
// straight into the existing CorrespondenceNotifier.importEml() pipeline
// without any new parsing code.

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../services/google_auth_service.dart';

class GmailMessageSummary {
  const GmailMessageSummary({
    required this.id,
    required this.subject,
    required this.from,
    required this.date,
    required this.snippet,
  });

  final String id;
  final String subject;
  final String from;
  final String? date;
  final String snippet;
}

/// One message within a [GmailThreadSummary] — metadata only, same shape
/// as [GmailMessageSummary] minus the (thread-level) subject.
class GmailThreadMessage {
  const GmailThreadMessage({
    required this.id,
    required this.from,
    required this.date,
    required this.snippet,
  });

  final String id;
  final String from;
  final String? date;
  final String snippet;
}

/// A Gmail conversation (thread) — the unit shown in the import picker so
/// the surveyor sees a full back-and-forth, not isolated messages.
class GmailThreadSummary {
  const GmailThreadSummary({
    required this.id,
    required this.subject,
    required this.messages,
  });

  final String id;
  final String subject;
  final List<GmailThreadMessage> messages;

  int get messageCount => messages.length;
  GmailThreadMessage get latest => messages.last;
}

class GmailService {
  GmailService._();

  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://gmail.googleapis.com/gmail/v1/users/me/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 2),
  ));

  static Future<Options> _authHeaders() async => Options(headers: {
        'Authorization': 'Bearer ${await GoogleAuthService.accessToken()}'
      });

  /// Same shape as [listRecent] (metadata-only summaries) but backed by
  /// [GoogleAuthService.silentAccessToken] — never triggers an interactive
  /// sign-in. Returns null if no session is silently available, meaning
  /// "skip this cycle" for a background caller. Used by the §3.14 mail
  /// poller; explicit user-initiated screens (Inbox, Correspondence import)
  /// keep using [listRecent], which is allowed to prompt.
  static Future<List<GmailMessageSummary>?> listRecentSilent({
    int maxResults = 10,
  }) async {
    final token = await GoogleAuthService.silentAccessToken();
    if (token == null) return null;
    final headers = Options(headers: {'Authorization': 'Bearer $token'});

    final listResp = await _dio.get<Map<String, dynamic>>(
      'messages',
      queryParameters: {'maxResults': maxResults},
      options: headers,
    );
    final ids = (listResp.data!['messages'] as List? ?? [])
        .map((m) => m['id'] as String)
        .toList();

    final summaries = <GmailMessageSummary>[];
    for (final id in ids) {
      final resp = await _dio.get<Map<String, dynamic>>(
        'messages/$id',
        queryParameters: {
          'format': 'metadata',
          'metadataHeaders': ['Subject', 'From', 'Date'],
        },
        options: headers,
      );
      final data = resp.data!;
      final hdrs = (data['payload']?['headers'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      String header(String name) =>
          hdrs.firstWhere((h) => h['name'] == name,
              orElse: () => const {})['value'] as String? ??
          '';

      summaries.add(GmailMessageSummary(
        id: id,
        subject: header('Subject').isEmpty ? '(no subject)' : header('Subject'),
        from: header('From'),
        date: header('Date').isEmpty ? null : header('Date'),
        snippet: data['snippet'] as String? ?? '',
      ));
    }
    return summaries;
  }

  /// Converts standard base64 to the URL-safe alphabet Gmail's API expects
  /// (and back) — RFC 4648 §5.
  static String _b64UrlEncode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _b64UrlDecode(String s) {
    final padded = s.padRight((s.length + 3) ~/ 4 * 4, '=');
    return base64Url.decode(padded.replaceAll('-', '+').replaceAll('_', '/'));
  }

  /// Lists the most recent messages in the inbox (metadata only — subject,
  /// from, date, snippet) for a picker UI. [query] uses Gmail search syntax
  /// (e.g. 'from:owner@ship.com') — null/empty lists the inbox as-is.
  static Future<List<GmailMessageSummary>> listRecent({
    int maxResults = 25,
    String? query,
  }) async {
    final listResp = await _dio.get<Map<String, dynamic>>(
      'messages',
      queryParameters: {
        'maxResults': maxResults,
        if (query != null && query.isNotEmpty) 'q': query,
      },
      options: await _authHeaders(),
    );
    final ids = (listResp.data!['messages'] as List? ?? [])
        .map((m) => m['id'] as String)
        .toList();

    final summaries = <GmailMessageSummary>[];
    final headers = await _authHeaders();
    for (final id in ids) {
      final resp = await _dio.get<Map<String, dynamic>>(
        'messages/$id',
        queryParameters: {
          'format': 'metadata',
          'metadataHeaders': ['Subject', 'From', 'Date'],
        },
        options: headers,
      );
      final data = resp.data!;
      final hdrs = (data['payload']?['headers'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      String header(String name) =>
          hdrs.firstWhere((h) => h['name'] == name,
              orElse: () => const {})['value'] as String? ??
          '';

      summaries.add(GmailMessageSummary(
        id: id,
        subject: header('Subject').isEmpty ? '(no subject)' : header('Subject'),
        from: header('From'),
        date: header('Date').isEmpty ? null : header('Date'),
        snippet: data['snippet'] as String? ?? '',
      ));
    }
    return summaries;
  }

  /// Lists conversations (threads) matching [query] — the natural unit for
  /// an import picker, since a case-relevant email is usually a back-and-forth
  /// rather than a single isolated message. For each thread found, fetches
  /// its full message list (metadata only) in one call so the picker can show
  /// the whole conversation before the surveyor commits to importing it.
  static Future<List<GmailThreadSummary>> listThreads({
    int maxResults = 20,
    String? query,
  }) async {
    final listResp = await _dio.get<Map<String, dynamic>>(
      'threads',
      queryParameters: {
        'maxResults': maxResults,
        if (query != null && query.isNotEmpty) 'q': query,
      },
      options: await _authHeaders(),
    );
    final ids = (listResp.data!['threads'] as List? ?? [])
        .map((t) => t['id'] as String)
        .toList();

    final threads = <GmailThreadSummary>[];
    final headers = await _authHeaders();
    for (final id in ids) {
      final resp = await _dio.get<Map<String, dynamic>>(
        'threads/$id',
        queryParameters: {
          'format': 'metadata',
          'metadataHeaders': ['Subject', 'From', 'Date'],
        },
        options: headers,
      );
      final rawMessages = (resp.data!['messages'] as List? ?? []);
      if (rawMessages.isEmpty) continue;

      String headerOf(Map<String, dynamic> msg, String name) {
        final hdrs = (msg['payload']?['headers'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        return hdrs.firstWhere((h) => h['name'] == name,
                orElse: () => const {})['value'] as String? ??
            '';
      }

      final messages = rawMessages.map((m) {
        final msg = m as Map<String, dynamic>;
        final date = headerOf(msg, 'Date');
        return GmailThreadMessage(
          id: msg['id'] as String,
          from: headerOf(msg, 'From'),
          date: date.isEmpty ? null : date,
          snippet: msg['snippet'] as String? ?? '',
        );
      }).toList();

      final subject =
          headerOf(rawMessages.first as Map<String, dynamic>, 'Subject');
      threads.add(GmailThreadSummary(
        id: id,
        subject: subject.isEmpty ? '(no subject)' : subject,
        messages: messages,
      ));
    }
    return threads;
  }

  /// Fetches the full raw RFC822 bytes of message [id] — feed directly into
  /// EmlParser.parse() / CorrespondenceNotifier.importEml().
  static Future<Uint8List> fetchRawMessage(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      'messages/$id',
      queryParameters: {'format': 'raw'},
      options: await _authHeaders(),
    );
    return _b64UrlDecode(resp.data!['raw'] as String);
  }

  /// Sends a plain-text email. [inReplyToRfc822MessageId] (the RFC822
  /// Message-ID header value, not the Gmail message id) sets the
  /// In-Reply-To/References headers so it threads as a reply in the
  /// recipient's client.
  static Future<void> sendMessage({
    required String to,
    required String subject,
    required String bodyText,
    String? inReplyToRfc822MessageId,
  }) async {
    final lines = [
      'To: $to',
      'Subject: =?UTF-8?B?${base64.encode(utf8.encode(subject))}?=',
      if (inReplyToRfc822MessageId != null) ...[
        'In-Reply-To: $inReplyToRfc822MessageId',
        'References: $inReplyToRfc822MessageId',
      ],
      'Content-Type: text/plain; charset="UTF-8"',
      'MIME-Version: 1.0',
      '',
      bodyText,
    ];
    final raw = _b64UrlEncode(utf8.encode(lines.join('\r\n')));

    await _dio.post<Map<String, dynamic>>(
      'messages/send',
      data: {'raw': raw},
      options: await _authHeaders(),
    );
  }
}
