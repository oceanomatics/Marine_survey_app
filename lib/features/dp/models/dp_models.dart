// lib/features/dp/models/dp_models.dart
//
// Data models for the DP FMEA Annual Trials module. Built on the existing
// `trials_tests` scaffold table (test register — each row is a witnessed test
// with a result and a finding category). Enums mirror the DB's
// test_result_enum / finding_category_enum verbatim. PK column is `test_id`.

import 'package:flutter/foundation.dart';

// test_result_enum: pass | fail | partial | not_tested | tbc
enum DpTestResult {
  pass('pass', 'Pass'),
  fail('fail', 'Fail'),
  partial('partial', 'Partial'),
  notTested('not_tested', 'Not tested'),
  tbc('tbc', 'TBC');

  const DpTestResult(this.value, this.label);
  final String value;
  final String label;

  static DpTestResult? fromValue(String? v) {
    if (v == null) return null;
    for (final r in values) {
      if (r.value == v) return r;
    }
    return null;
  }
}

// finding_category_enum: pass | finding | observation | recommendation | critical
enum DpFindingCategory {
  pass('pass', 'Pass'),
  finding('finding', 'Finding'),
  observation('observation', 'Observation'),
  recommendation('recommendation', 'Recommendation'),
  critical('critical', 'Critical');

  const DpFindingCategory(this.value, this.label);
  final String value;
  final String label;

  static DpFindingCategory? fromValue(String? v) {
    if (v == null) return null;
    for (final c in values) {
      if (c.value == v) return c;
    }
    return null;
  }
}

@immutable
class DpTestModel {
  const DpTestModel({
    required this.testId,
    required this.caseId,
    this.testNo,
    this.testName,
    this.system,
    this.result,
    this.findingCategory,
    this.observations,
    this.wcfTested = false,
    this.carriedForward = false,
    this.createdAt,
    this.updatedAt,
  });

  final String testId;
  final String caseId;
  final int? testNo;
  final String? testName;
  final String? system;
  final DpTestResult? result;
  final DpFindingCategory? findingCategory;
  final String? observations;

  /// Worst-case failure tested by this test.
  final bool wcfTested;

  /// Carried forward from a prior trial (not re-tested this cycle).
  final bool carriedForward;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DpTestModel.fromJson(Map<String, dynamic> j) => DpTestModel(
        testId: j['test_id'] as String,
        caseId: j['case_id'] as String,
        testNo: j['test_no'] as int?,
        testName: j['test_name'] as String?,
        system: j['system'] as String?,
        result: DpTestResult.fromValue(j['result'] as String?),
        findingCategory:
            DpFindingCategory.fromValue(j['finding_category'] as String?),
        observations: j['observations'] as String?,
        wcfTested: j['wcf_tested'] as bool? ?? false,
        carriedForward: j['carried_forward'] as bool? ?? false,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );

  DpTestModel copyWith({
    String? testName,
    String? system,
    DpTestResult? result,
    DpFindingCategory? findingCategory,
    String? observations,
    bool? wcfTested,
    bool? carriedForward,
  }) =>
      DpTestModel(
        testId: testId,
        caseId: caseId,
        testNo: testNo,
        testName: testName ?? this.testName,
        system: system ?? this.system,
        result: result ?? this.result,
        findingCategory: findingCategory ?? this.findingCategory,
        observations: observations ?? this.observations,
        wcfTested: wcfTested ?? this.wcfTested,
        carriedForward: carriedForward ?? this.carriedForward,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
