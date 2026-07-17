// lib/core/utils/mail_text.dart
//
// Decoding helpers for text pulled from the Gmail API (Inbox / Triage).
//
//  * Gmail message *snippets* are HTML-escaped — "he&#39;s" instead of "he's".
//  * Header values (Subject / From) can arrive as RFC 2047 "encoded-words"
//    (e.g. "=?UTF-8?B?V8OhbmvDvA==?=") which render as mojibake ("WÃ¡nkÃ¼")
//    unless decoded, and may additionally contain HTML entities.
//
// These helpers are dependency-free and safe on already-clean strings
// (a plain "Neptune Shipping" passes through untouched).

import 'dart:convert';

/// Decodes HTML character references (named + numeric) in [input].
///
/// Handles the common named entities plus decimal (`&#39;`) and hexadecimal
/// (`&#x27;`) numeric references. Unknown entities are left verbatim.
String decodeHtmlEntities(String input) {
  if (!input.contains('&')) return input;

  return input.replaceAllMapped(
    RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);'),
    (m) {
      final body = m.group(1)!;
      if (body.startsWith('#')) {
        final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
        final digits = isHex ? body.substring(2) : body.substring(1);
        final code = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
        try {
          return String.fromCharCode(code);
        } catch (_) {
          return m.group(0)!;
        }
      }
      return _namedEntities[body] ?? m.group(0)!;
    },
  );
}

const Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u0020', // normalise to a regular space
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'deg': '°',
  'eacute': 'é',
  'egrave': 'è',
  'agrave': 'à',
  'aacute': 'á',
  'uuml': 'ü',
  'ouml': 'ö',
  'auml': 'ä',
  'ntilde': 'ñ',
  'ccedil': 'ç',
};

/// Decodes RFC 2047 "encoded-words" (`=?charset?B|Q?data?=`) in a MIME header
/// value, then decodes any HTML entities. Whitespace separating two adjacent
/// encoded-words is removed, per the spec.
String decodeMailHeader(String input) {
  if (input.isEmpty) return input;

  var out = input;
  if (out.contains('=?')) {
    // Collapse whitespace between adjacent encoded-words first.
    out = out.replaceAllMapped(
      RegExp(r'\?=\s+=\?'),
      (_) => '?==?',
    );
    out = out.replaceAllMapped(
      RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?='),
      (m) {
        final charset = m.group(1)!.toLowerCase();
        final enc = m.group(2)!.toUpperCase();
        final data = m.group(3)!;
        try {
          final bytes = enc == 'B'
              ? base64.decode(_padBase64(data.replaceAll(' ', '')))
              : _decodeQ(data);
          return _decodeBytes(bytes, charset);
        } catch (_) {
          return m.group(0)!;
        }
      },
    );
  }
  return decodeHtmlEntities(out);
}

/// Decodes a Gmail snippet / body-preview string: HTML entities only.
String decodeMailText(String input) => decodeHtmlEntities(input);

String _padBase64(String s) {
  final mod = s.length % 4;
  if (mod == 0) return s;
  return s + '=' * (4 - mod);
}

List<int> _decodeQ(String data) {
  final bytes = <int>[];
  for (var i = 0; i < data.length; i++) {
    final ch = data[i];
    if (ch == '_') {
      bytes.add(0x20); // RFC 2047: '_' represents a space
    } else if (ch == '=' && i + 2 < data.length) {
      final hex = data.substring(i + 1, i + 3);
      final code = int.tryParse(hex, radix: 16);
      if (code != null) {
        bytes.add(code);
        i += 2;
      } else {
        bytes.add(ch.codeUnitAt(0));
      }
    } else {
      bytes.add(ch.codeUnitAt(0));
    }
  }
  return bytes;
}

String _decodeBytes(List<int> bytes, String charset) {
  switch (charset) {
    case 'utf-8':
    case 'utf8':
      return utf8.decode(bytes, allowMalformed: true);
    case 'iso-8859-1':
    case 'latin1':
    case 'windows-1252':
    case 'cp1252':
    case 'us-ascii':
    case 'ascii':
      return latin1.decode(bytes, allowInvalid: true);
    default:
      // Best effort: try UTF-8, which is by far the most common.
      return utf8.decode(bytes, allowMalformed: true);
  }
}
