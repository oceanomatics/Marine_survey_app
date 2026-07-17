import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/core/utils/mail_text.dart';

void main() {
  group('decodeHtmlEntities', () {
    test('decodes numeric decimal apostrophe (&#39;)', () {
      expect(decodeHtmlEntities('he&#39;s aboard'), "he's aboard");
    });

    test('decodes hex numeric reference (&#x27;)', () {
      expect(decodeHtmlEntities('it&#x27;s fine'), "it's fine");
    });

    test('decodes the common named entities', () {
      expect(
        decodeHtmlEntities('Smith &amp; Jones &lt;tag&gt; &quot;q&quot;'),
        'Smith & Jones <tag> "q"',
      );
    });

    test('decodes &nbsp; to a space', () {
      expect(decodeHtmlEntities('a&nbsp;b'), 'a b');
    });

    test('leaves clean text untouched', () {
      expect(decodeHtmlEntities('Neptune Shipping'), 'Neptune Shipping');
    });

    test('leaves unknown entities verbatim', () {
      expect(decodeHtmlEntities('a &bogus; b'), 'a &bogus; b');
    });
  });

  group('decodeMailHeader (RFC 2047 encoded-words)', () {
    test('decodes a UTF-8 base64 encoded-word (fixes mojibake)', () {
      // "Wánk" -> UTF-8 bytes -> base64
      expect(decodeMailHeader('=?UTF-8?B?V8Ohbms=?='), 'Wánk');
    });

    test('decodes a UTF-8 quoted-printable encoded-word', () {
      expect(decodeMailHeader('=?UTF-8?Q?W=C3=A1nk?='), 'Wánk');
    });

    test('Q-encoding maps underscore to space', () {
      expect(decodeMailHeader('=?UTF-8?Q?John_Smith?='), 'John Smith');
    });

    test('decodes an encoded name embedded in a From header', () {
      expect(
        decodeMailHeader('=?UTF-8?B?V8Ohbms=?= <wank@ship.com>'),
        'Wánk <wank@ship.com>',
      );
    });

    test('joins adjacent encoded-words dropping the separating whitespace', () {
      // "Wá" + "nk" as two encoded-words -> "Wánk"
      expect(
        decodeMailHeader('=?UTF-8?B?V8Oh?= =?UTF-8?B?bms=?='),
        'Wánk',
      );
    });

    test('decodes ISO-8859-1 quoted-printable', () {
      expect(decodeMailHeader('=?ISO-8859-1?Q?Fran=E7ois?='), 'François');
    });

    test('also decodes HTML entities present in a header', () {
      expect(decodeMailHeader('Smith &amp; Co'), 'Smith & Co');
    });

    test('passes a plain header through untouched', () {
      expect(decodeMailHeader('Neptune Shipping'), 'Neptune Shipping');
    });
  });
}
