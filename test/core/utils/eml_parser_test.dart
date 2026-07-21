import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/utils/eml_parser.dart';

Uint8List _eml(String raw) => Uint8List.fromList(utf8.encode(raw));

void main() {
  group('EmlParser header decoding', () {
    test('decodes HTML entities in a plain header (bug 2 residual)', () {
      final msg = _eml(
        'Subject: O&#39;Brien&#39;s vessel &amp; cargo\r\n'
        'From: crew@example.com\r\n'
        'To: surveyor@example.com\r\n'
        '\r\n'
        'body\r\n',
      );
      final parsed = EmlParser.parse(msg);
      expect(parsed.subject, "O'Brien's vessel & cargo");
    });

    test('decodes RFC 2047 MIME words in the From header', () {
      final msg = _eml(
        'Subject: hi\r\n'
        'From: =?UTF-8?B?V8Ohbms=?= <w@example.com>\r\n'
        'To: surveyor@example.com\r\n'
        '\r\n'
        'body\r\n',
      );
      final parsed = EmlParser.parse(msg);
      expect(parsed.from, contains('Wánk'));
    });

    test('decodes MIME words AND HTML entities together', () {
      final msg = _eml(
        'Subject: =?UTF-8?Q?Report?= &#8211; final\r\n'
        'From: a@example.com\r\n'
        'To: b@example.com\r\n'
        '\r\n'
        'body\r\n',
      );
      final parsed = EmlParser.parse(msg);
      expect(parsed.subject, 'Report – final');
    });
  });
}
