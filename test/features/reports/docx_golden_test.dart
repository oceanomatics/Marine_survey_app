// F0 — H&M .docx golden guard.
//
// Snapshots the current H&M report output (the inner OOXML text entries) so a
// later exporter refactor (F3, branching the assembler per case_type) cannot
// silently change H&M output. Compares the unzipped XML entries — NOT the
// zipped bytes — to avoid archive-timestamp / compression flakiness, and gives
// readable diffs. The one nondeterministic source (the "date issued") is
// pinned via buildDocx(asOf: ...).
//
// Re-bless after an *intentional* output change:
//     UPDATE_GOLDENS=1 flutter test test/features/reports/docx_golden_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marine_survey_app/features/reports/providers/report_provider.dart';
import 'package:marine_survey_app/features/reports/services/docx_export_service.dart';

import '../../support/fixtures/report_fixtures.dart';

final _fixedDate = DateTime(2026, 1, 1);
const _goldenDir = 'test/goldens/docx';
final _update = Platform.environment['UPDATE_GOLDENS'] == '1';

bool _isTextEntry(String name) =>
    name.endsWith('.xml') || name.endsWith('.rels');

/// Unzip → { entry-path : xml text }, text entries only (skip embedded images).
Map<String, String> _unzipXml(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final out = <String, String>{};
  for (final f in archive.files) {
    if (f.isFile && _isTextEntry(f.name)) {
      out[f.name] = utf8.decode(f.content as List<int>);
    }
  }
  return out;
}

String _fileFor(String caseName, String entry) =>
    '$_goldenDir/$caseName/${entry.replaceAll('/', '__')}';

void _checkGolden(String caseName, Map<String, String> entries) {
  if (_update) {
    final dir = Directory('$_goldenDir/$caseName');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    entries.forEach((name, content) {
      File(_fileFor(caseName, name)).writeAsStringSync(content);
    });
    return;
  }

  final dir = Directory('$_goldenDir/$caseName');
  expect(dir.existsSync(), isTrue,
      reason: 'No goldens for "$caseName". Create them once with '
          'UPDATE_GOLDENS=1 flutter test <this file>.');

  final goldenEntries = <String>{};
  for (final gf in dir.listSync().whereType<File>()) {
    final entry =
        gf.uri.pathSegments.last.replaceAll('__', '/');
    goldenEntries.add(entry);
    expect(entries.containsKey(entry), isTrue,
        reason: 'Exporter no longer emits "$entry" for $caseName — output '
            'changed. Review, then re-bless with UPDATE_GOLDENS=1.');
    expect(entries[entry], gf.readAsStringSync(),
        reason: 'Golden mismatch in "$entry" for $caseName — H&M .docx output '
            'changed. Review the diff; if intentional, re-bless with '
            'UPDATE_GOLDENS=1.');
  }
  // A new entry the goldens don't know about is also a change.
  for (final name in entries.keys) {
    expect(goldenEntries.contains(name), isTrue,
        reason: 'Exporter emits NEW entry "$name" for $caseName not in the '
            'goldens — review, then re-bless with UPDATE_GOLDENS=1.');
  }
}

void main() {
  group('H&M .docx golden guard (F0)', () {
    // Covers the three OutputType switch branches — the parts most at risk in F3.
    for (final ot in const [
      OutputType.preliminary,
      OutputType.advice,
      OutputType.final_,
    ]) {
      test('output=${ot.name} inner XML is byte-stable', () {
        final bytes = DocxExportService.buildDocx(
          fixtureOutput(outputType: ot),
          fixtureAssembledData(),
          fixtureAllSections(),
          asOf: _fixedDate,
        );
        _checkGolden(ot.name, _unzipXml(bytes));
      });
    }
  });
}
