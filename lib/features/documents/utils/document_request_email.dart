// lib/features/documents/utils/document_request_email.dart
//
// Auto-generated "Documentation Request" email (TODO.md §3.4, 8 July 2026)
// — composes a subject/body listing outstanding requested documents from
// the case's actual DocumentModel records, so the surveyor doesn't have
// to hand-type the list. Pure/deterministic, no AI involved.

import '../providers/document_provider.dart';
import '../../cases/models/case_model.dart';

class DocumentRequestEmail {
  const DocumentRequestEmail({required this.subject, required this.body});
  final String subject;
  final String body;
}

/// [requested] should already be filtered to
/// `availability == DocAvailability.requested`.
DocumentRequestEmail buildDocumentRequestEmail({
  required CaseModel caseModel,
  required List<DocumentModel> requested,
}) {
  final vessel = caseModel.vesselName ?? caseModel.title ?? caseModel.technicalFileNo;
  final subject = 'Documentation Request — $vessel (${caseModel.technicalFileNo})';

  final buf = StringBuffer()
    ..writeln('Dear Sirs,')
    ..writeln()
    ..writeln('In connection with our ongoing survey of the above vessel, '
        'we would be grateful if you could kindly provide the following '
        'outstanding documentation at your earliest convenience:')
    ..writeln();

  for (final doc in requested) {
    final requestedSince = doc.requestedDate != null
        ? ' (requested ${_fmtDate(doc.requestedDate!)})'
        : '';
    buf.writeln('  • ${doc.title}$requestedSince');
  }

  buf
    ..writeln()
    ..writeln('Please do not hesitate to contact us should you have any '
        'queries regarding the above.')
    ..writeln()
    ..writeln('Kind regards,');

  return DocumentRequestEmail(subject: subject, body: buf.toString());
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
