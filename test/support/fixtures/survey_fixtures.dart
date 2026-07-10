import 'package:marine_survey_app/features/survey/providers/damage_provider.dart';
import 'package:marine_survey_app/features/survey/providers/attendees_provider.dart';
import 'package:marine_survey_app/features/survey/models/repair_period_model.dart';

OccurrenceModel fixtureOccurrence({
  String occurrenceId = 'occ-1',
  String caseId = 'case-1',
  int occurrenceNo = 1,
  bool isPrimary = true,
  String? title = 'Main diesel generator No.3 — connecting rod cap failure',
  DateTime? dateTime,
  String? location,
  String? briefDescription,
}) =>
    OccurrenceModel(
      occurrenceId: occurrenceId,
      caseId: caseId,
      occurrenceNo: occurrenceNo,
      isPrimary: isPrimary,
      title: title,
      dateTime: dateTime,
      location: location,
      briefDescription: briefDescription,
      createdAt: DateTime(2026, 1, 1),
    );

DamageItemModel fixtureDamageItem({
  String damageId = 'dmg-1',
  String occurrenceId = 'occ-1',
  String caseId = 'case-1',
  String componentName = 'No.3 Diesel Generator',
  DamageCategory damageCategory = DamageCategory.mechanical,
  String? machineryId,
  int sequenceNo = 1,
  bool isConcerningAverage = true,
}) =>
    DamageItemModel(
      damageId: damageId,
      occurrenceId: occurrenceId,
      caseId: caseId,
      componentName: componentName,
      damageCategory: damageCategory,
      machineryId: machineryId,
      sequenceNo: sequenceNo,
      isConcerningAverage: isConcerningAverage,
    );

DamageState fixtureDamageState({
  List<OccurrenceModel> occurrences = const [],
  List<DamageItemModel> damageItems = const [],
  List<RepairModel> repairs = const [],
}) =>
    DamageState(
      occurrences: occurrences,
      damageItems: damageItems,
      repairs: repairs,
    );

AttendeeModel fixtureAttendee({
  String attendeeId = 'att-1',
  String caseId = 'case-1',
  String fullName = 'John Samuel',
  AttendeeTitle? title,
  String? rankPosition = 'Master',
  AttendeeRole? roleType = AttendeeRole.master,
  String? company,
}) =>
    AttendeeModel(
      attendeeId: attendeeId,
      caseId: caseId,
      fullName: fullName,
      title: title,
      rankPosition: rankPosition,
      roleType: roleType,
      company: company,
    );

RepairPeriodModel fixtureRepairPeriod({
  String periodId = 'period-1',
  String caseId = 'case-1',
  int periodNo = 1,
  String? title,
  DateTime? startDate,
  DateTime? endDate,
  String? location,
  PortContext portContext = PortContext.planned,
  List<RepairAssignmentModel> assignments = const [],
}) =>
    RepairPeriodModel(
      periodId: periodId,
      caseId: caseId,
      periodNo: periodNo,
      title: title,
      startDate: startDate,
      endDate: endDate,
      location: location,
      portContext: portContext,
      assignments: assignments,
    );
