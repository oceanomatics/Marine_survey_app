// lib/core/utils/eml_parser.dart
//
// Minimal RFC 2822 / MIME EML parser.
// Handles multipart/mixed, multipart/alternative, base64 and quoted-printable.
// No external packages — pure Dart.

import 'dart:convert';
import 'dart:typed_data';

import 'mail_text.dart' show decodeHtmlEntities;

class EmlMessage {
  const EmlMessage({
    required this.subject,
    required this.from,
    required this.to,
    this.date,
    required this.plainBody,
    required this.attachments,
  });

  final String subject;
  final String from;
  final String to;
  final DateTime? date;
  final String plainBody;
  final List<EmlAttachment> attachments;
}

class EmlAttachment {
  const EmlAttachment({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final Uint8List bytes;

  double get sizeKb => bytes.length / 1024;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  String get displaySize => sizeKb < 1024
      ? '${sizeKb.toStringAsFixed(0)} KB'
      : '${(sizeKb / 1024).toStringAsFixed(1)} MB';
}

class EmlParser {
  static EmlMessage parse(Uint8List rawBytes) {
    String raw;
    try {
      raw = utf8.decode(rawBytes, allowMalformed: true);
    } catch (_) {
      raw = latin1.decode(rawBytes);
    }

    // Normalise CRLF → LF
    raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final sepIdx = raw.indexOf('\n\n');
    final headerSection = sepIdx == -1 ? raw : raw.substring(0, sepIdx);
    final bodySection = sepIdx == -1 ? '' : raw.substring(sepIdx + 2);

    final headers = _parseHeaders(headerSection);
    final contentType = headers['content-type'] ?? '';

    String plainBody = '';
    final attachments = <EmlAttachment>[];

    if (_isMultipart(contentType)) {
      final boundary = _extractBoundary(contentType);
      if (boundary != null) {
        _processMultipart(bodySection, boundary, attachments, (t) {
          if (plainBody.isEmpty) plainBody = t;
        });
      }
    } else {
      final cte = (headers['content-transfer-encoding'] ?? '').toLowerCase().trim();
      plainBody = _decodeTextBody(bodySection, cte);
    }

    return EmlMessage(
      subject: _decodeHeader(headers['subject'] ?? '(No Subject)'),
      from: _decodeHeader(headers['from'] ?? ''),
      to: _decodeHeader(headers['to'] ?? ''),
      date: _parseRfc2822Date(headers['date']),
      plainBody: plainBody.trim(),
      attachments: attachments,
    );
  }

  // ── Header parsing ─────────────────────────────────────────────────────────

  static Map<String, String> _parseHeaders(String section) {
    // Unfold: continuation lines start with whitespace
    final unfolded = section.replaceAll(RegExp(r'\n[ \t]+'), ' ');
    final result = <String, String>{};
    for (final line in unfolded.split('\n')) {
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      // Keep first occurrence (subsequent Received: headers etc.)
      result.putIfAbsent(key, () => value);
    }
    return result;
  }

  // RFC 2047 encoded-word decoder: =?charset?B/Q?data?=
  static String _decodeHeader(String value) {
    final decoded = value.replaceAllMapped(
      RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?='),
      (m) {
        final enc = m.group(2)!.toUpperCase();
        final data = m.group(3)!;
        try {
          if (enc == 'B') {
            return utf8.decode(base64Decode(data.replaceAll(' ', '')),
                allowMalformed: true);
          } else {
            // Q encoding: _ = space
            return _decodeQP(data.replaceAll('_', ' '));
          }
        } catch (_) {
          return data;
        }
      },
    );
    // Filed correspondence (imported .eml) also carries HTML entities in
    // headers (e.g. &#39; apostrophes, &amp;) — decode them too, matching the
    // Gmail path (decodeMailHeader) so subjects/senders read cleanly.
    return decodeHtmlEntities(decoded);
  }

  // ── Multipart ──────────────────────────────────────────────────────────────

  static bool _isMultipart(String ct) =>
      ct.toLowerCase().contains('multipart/');

  static String? _extractBoundary(String ct) {
    final m = RegExp(r'boundary="?([^";]+)"?', caseSensitive: false)
        .firstMatch(ct);
    return m?.group(1)?.trim();
  }

  static void _processMultipart(
    String body,
    String boundary,
    List<EmlAttachment> attachments,
    void Function(String) onPlainText,
  ) {
    final startMarker = '--$boundary';
    final endMarker = '--$boundary--';

    final lines = body.split('\n');
    final parts = <String>[];
    StringBuffer? cur;

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed == endMarker) {
        if (cur != null) parts.add(cur.toString());
        break;
      } else if (trimmed == startMarker) {
        if (cur != null) parts.add(cur.toString());
        cur = StringBuffer();
      } else if (cur != null) {
        cur.writeln(line);
      }
    }
    // Handle missing end marker
    if (cur != null && cur.isNotEmpty) parts.add(cur.toString());

    for (final part in parts) {
      _processPart(part, attachments, onPlainText);
    }
  }

  static void _processPart(
    String partContent,
    List<EmlAttachment> attachments,
    void Function(String) onPlainText,
  ) {
    final sepIdx = partContent.indexOf('\n\n');
    if (sepIdx == -1) return;

    final headerStr = partContent.substring(0, sepIdx);
    final body = partContent.substring(sepIdx + 2);
    final headers = _parseHeaders(headerStr);

    final ct = headers['content-type'] ?? 'text/plain';
    final ctLower = ct.toLowerCase();
    final cte = (headers['content-transfer-encoding'] ?? '').toLowerCase().trim();
    final cd = (headers['content-disposition'] ?? '').toLowerCase();

    if (_isMultipart(ctLower)) {
      final boundary = _extractBoundary(ct);
      if (boundary != null) {
        _processMultipart(body, boundary, attachments, onPlainText);
      }
      return;
    }

    final filename = _extractFilename(headers);

    if (cd.startsWith('attachment') ||
        (filename != null && !ctLower.startsWith('text/'))) {
      if (filename != null) {
        final bytes = _decodeBinaryBody(body, cte);
        final mimeType = ctLower.split(';').first.trim();
        attachments.add(EmlAttachment(
          filename: filename,
          mimeType: mimeType,
          bytes: bytes,
        ));
      }
    } else if (ctLower.startsWith('text/plain')) {
      onPlainText(_decodeTextBody(body, cte));
    }
    // text/html: ignored (we only need plain text)
  }

  // ── Filename extraction ────────────────────────────────────────────────────

  static String? _extractFilename(Map<String, String> headers) {
    for (final header in ['content-disposition', 'content-type']) {
      final val = headers[header] ?? '';
      final m = RegExp(r'filename\*?="?([^";]+)"?', caseSensitive: false)
          .firstMatch(val);
      if (m != null) return _decodeHeader(m.group(1)!.trim());
      final m2 = RegExp(r'name\*?="?([^";]+)"?', caseSensitive: false)
          .firstMatch(val);
      if (m2 != null) return _decodeHeader(m2.group(1)!.trim());
    }
    return null;
  }

  // ── Body decoding ──────────────────────────────────────────────────────────

  static String _decodeTextBody(String body, String cte) {
    switch (cte) {
      case 'base64':
        final cleaned = body.replaceAll(RegExp(r'\s'), '');
        try {
          return utf8.decode(base64Decode(cleaned), allowMalformed: true);
        } catch (_) {
          return body;
        }
      case 'quoted-printable':
        return _decodeQP(body);
      default:
        return body;
    }
  }

  static Uint8List _decodeBinaryBody(String body, String cte) {
    if (cte == 'base64') {
      final cleaned = body.replaceAll(RegExp(r'\s'), '');
      try {
        return base64Decode(cleaned);
      } catch (_) {
        return Uint8List(0);
      }
    }
    return Uint8List.fromList(utf8.encode(body));
  }

  static String _decodeQP(String text) {
    // Remove soft line breaks (=\n)
    final soft = text.replaceAll('=\n', '');
    // Decode =XX hex sequences
    return soft.replaceAllMapped(
      RegExp(r'=([0-9A-Fa-f]{2})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
  }

  // ── Date parsing ───────────────────────────────────────────────────────────

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // RFC 2822: "Mon, 23 Jun 2026 10:30:00 +1000" or without day name
  static DateTime? _parseRfc2822Date(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      // Remove optional "Day, " prefix
      var s = dateStr.replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '').trim();
      final re = RegExp(
        r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
        r'(\d{2}):(\d{2}):(\d{2})\s*([+-]\d{2}:?\d{2})?',
      );
      final m = re.firstMatch(s);
      if (m == null) return null;

      final day = int.parse(m.group(1)!);
      final month = _months[m.group(2)!.toLowerCase()] ?? 1;
      final year = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      final second = int.parse(m.group(6)!);

      int tzOffsetSeconds = 0;
      final tzStr = m.group(7);
      if (tzStr != null) {
        final sign = tzStr.startsWith('+') ? 1 : -1;
        final digits = tzStr.replaceAll(':', '').substring(1);
        if (digits.length == 4) {
          final h = int.parse(digits.substring(0, 2));
          final min = int.parse(digits.substring(2, 4));
          tzOffsetSeconds = sign * (h * 3600 + min * 60);
        }
      }

      final utc = DateTime.utc(year, month, day, hour, minute, second)
          .subtract(Duration(seconds: tzOffsetSeconds));
      return utc.toLocal();
    } catch (_) {
      return null;
    }
  }
}
