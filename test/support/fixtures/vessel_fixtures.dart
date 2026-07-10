import 'package:marine_survey_app/features/cases/models/case_model.dart';
import 'package:marine_survey_app/features/vessel/providers/certificates_provider.dart';
import 'package:marine_survey_app/features/vessel/providers/vessel_provider.dart';
import 'package:marine_survey_app/features/vessel/models/class_condition_model.dart';

VesselModel fixtureVessel({
  String vesselId = 'vessel-1',
  String name = 'MINRES ODIN',
  String? imoNumber,
  String? vesselType,
  RegulatoryStandard? regulatoryStandard,
}) =>
    VesselModel(
      vesselId: vesselId,
      name: name,
      imoNumber: imoNumber,
      vesselType: vesselType,
      regulatoryStandard: regulatoryStandard,
    );

MachineryModel fixtureMachinery({
  String machineryId = 'mach-1',
  String vesselId = 'vessel-1',
  String machineryType = 'main_engine',
  String? role = 'main_engine',
  String? make = 'MAN B&W',
  String? model,
  String? unitNumber,
}) =>
    MachineryModel(
      machineryId: machineryId,
      vesselId: vesselId,
      machineryType: machineryType,
      role: role,
      make: make,
      model: model,
      unitNumber: unitNumber,
    );

CertificateModel fixtureCertificate({
  String certId = 'cert-1',
  String caseId = 'case-1',
  CertType certType = CertType.classCertificate,
  String? certName,
  CertStatus status = CertStatus.valid,
}) =>
    CertificateModel(
      certId: certId,
      caseId: caseId,
      certType: certType,
      certName: certName,
      status: status,
    );

ClassConditionModel fixtureClassCondition({
  String conditionId = 'cond-1',
  String vesselId = 'vessel-1',
  String? reference = 'CoC-01',
  String? description = 'Renew anodes within 6 months',
  bool occurrenceRelated = false,
  String? occurrenceId,
}) =>
    ClassConditionModel(
      conditionId: conditionId,
      vesselId: vesselId,
      reference: reference,
      description: description,
      occurrenceRelated: occurrenceRelated,
      occurrenceId: occurrenceId,
    );
