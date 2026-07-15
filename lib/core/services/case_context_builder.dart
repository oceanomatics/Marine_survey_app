// lib/core/services/case_context_builder.dart

import '../../features/accounts/models/accounts_models.dart';
import '../../features/cases/models/case_model.dart';
import '../../features/survey/providers/damage_provider.dart';
import '../../features/surveyor_notes/models/surveyor_note_model.dart';
import '../../features/interviews/models/interview_model.dart';
import '../../features/correspondence/models/correspondence_model.dart';
import '../../features/documents/providers/document_provider.dart';
import '../../features/parties/models/party_model.dart';
import '../../features/photos/models/photo_model.dart';

/// Assembles all available case data into a plain-text context string
/// suitable for injection into the Claude system prompt.
class CaseContextBuilder {
  static String build({
    required CaseModel? caseData,
    required VesselModel? vessel,
    required DamageState? damage,
    required List<SurveyorNote>? notes,
    List<RepairDocumentModel>? repairDocuments,
    List<CostEstimateItemModel>? costEstimateItems,
    List<InterviewModel>? interviews,
    List<CorrespondenceModel>? correspondence,
    List<DocumentModel>? documents,
    CasePartiesModel? parties,
    List<AssuredContactModel>? contacts,
    List<PhotoModel>? photos,
  }) {
    final buf = StringBuffer();

    // ── Case overview ────────────────────────────────────────────────────────
    buf.writeln('## CASE OVERVIEW');
    if (caseData != null) {
      buf.writeln('Technical file no.: ${caseData.technicalFileNo}');
      buf.writeln('Type: ${caseData.caseType.label}');
      buf.writeln('Status: ${caseData.status.label}');
      if (caseData.claimReference != null) {
        buf.writeln('Claim reference: ${caseData.claimReference}');
      }
      if (caseData.instructionDate != null) {
        buf.writeln('Instructed: ${_fmtDate(caseData.instructionDate!)}');
      }
      if (caseData.title != null) buf.writeln('Title: ${caseData.title}');
    } else {
      buf.writeln('(case data not loaded)');
    }
    buf.writeln();

    // ── Vessel ───────────────────────────────────────────────────────────────
    buf.writeln('## VESSEL PARTICULARS');
    if (vessel != null) {
      buf.writeln('Name: ${vessel.name}');
      if (vessel.imoNumber != null) buf.writeln('IMO: ${vessel.imoNumber}');
      if (vessel.vesselType != null) buf.writeln('Type: ${vessel.vesselType}');
      if (vessel.flag != null) buf.writeln('Flag: ${vessel.flag}');
      if (vessel.yearBuilt != null) buf.writeln('Year built: ${vessel.yearBuilt}');
      if (vessel.classSociety != null) {
        final notation = vessel.classNotation != null ? ' (${vessel.classNotation})' : '';
        buf.writeln('Class: ${vessel.classSociety}$notation');
      }
      if (vessel.grossTonnage != null) {
        buf.writeln('GT: ${vessel.grossTonnage!.toStringAsFixed(0)} t');
      }
      if (vessel.deadweight != null) {
        buf.writeln('DWT: ${vessel.deadweight!.toStringAsFixed(0)} t');
      }
      if (vessel.owners != null) buf.writeln('Owners: ${vessel.owners}');
      if (vessel.operators != null) buf.writeln('Operators: ${vessel.operators}');
    } else {
      buf.writeln('(vessel data not loaded)');
    }
    buf.writeln();

    // ── Parties & contacts ─────────────────────────────────────────────────
    if (parties != null || (contacts != null && contacts.isNotEmpty)) {
      buf.writeln('## PARTIES');
      if (parties != null) {
        if (parties.principalName != null) {
          buf.writeln('Instructing principal: ${parties.principalName}'
              '${parties.principalCompany != null ? " (${parties.principalCompany})" : ""}');
        }
        if (parties.underwriterName != null) {
          buf.writeln('Underwriter: ${parties.underwriterName}'
              '${parties.underwriterCompany != null ? " (${parties.underwriterCompany})" : ""}');
        }
        if (parties.adjusterName != null) {
          buf.writeln('Adjuster: ${parties.adjusterName}'
              '${parties.adjusterCompany != null ? " (${parties.adjusterCompany})" : ""}');
        }
        if (parties.assuredRepName != null) {
          buf.writeln('Assured/owner\'s representative: ${parties.assuredRepName}'
              '${parties.assuredRepCompany != null ? " (${parties.assuredRepCompany})" : ""}');
        }
      }
      if (contacts != null && contacts.isNotEmpty) {
        buf.writeln('Contacts:');
        for (final c in contacts) {
          final role = c.roleTitle != null ? ' — ${c.roleTitle}' : '';
          final company = c.company != null ? ' (${c.company})' : '';
          buf.writeln('  - ${c.fullName}$role$company [${c.stakeholderGroup?.label ?? "Other"}]');
        }
      }
      buf.writeln();
    }

    // ── Occurrences ─────────────────────────────────────────────────────────
    if (damage != null && damage.occurrences.isNotEmpty) {
      buf.writeln('## OCCURRENCES');
      final primary = damage.primaryOccurrence;
      for (final occ in damage.occurrences) {
        final tag = (primary != null && occ.occurrenceId == primary.occurrenceId)
            ? ' [PRIMARY]'
            : '';
        buf.writeln(
            '### Occurrence ${occ.occurrenceNo}${occ.title != null ? ": ${occ.title}" : ""}$tag');
        if (occ.dateTime != null) {
          buf.writeln('Date/time: ${_fmtDate(occ.dateTime!)}');
        }
        if (occ.location != null) buf.writeln('Location: ${occ.location}');
        if (occ.briefDescription != null) {
          buf.writeln('Description: ${occ.briefDescription}');
        }
        if (occ.backgroundNarrative != null &&
            occ.backgroundNarrative!.isNotEmpty) {
          buf.writeln('Background: ${occ.backgroundNarrative}');
        }
        if (occ.causeType != null) buf.writeln('Cause type: ${occ.causeType}');
        if (occ.causeNarrative != null && occ.causeNarrative!.isNotEmpty) {
          buf.writeln('Cause narrative: ${occ.causeNarrative}');
        }
        buf.writeln();
      }
    }

    // ── Damage register ──────────────────────────────────────────────────────
    if (damage != null && damage.damageItems.isNotEmpty) {
      buf.writeln('## DAMAGE REGISTER');
      buf.writeln('Total items: ${damage.totalDamageItems} '
          '(${damage.averageItems} concerning average, '
          '${damage.ownerItems} owner\'s items)');
      buf.writeln();

      // Group by occurrence
      for (final occ in damage.occurrences) {
        final items = damage.itemsForOccurrence(occ.occurrenceId);
        if (items.isEmpty) continue;
        final occLabel = occ.title ?? 'Occurrence ${occ.occurrenceNo}';
        buf.writeln('Occurrence: $occLabel');
        for (final item in items) {
          final ca = item.isConcerningAverage ? ' [CA]' : '';
          buf.writeln('  ${item.sequenceNo}. ${item.componentName}$ca');
          if (item.locationOnVessel != null) {
            buf.writeln('     Location: ${item.locationOnVessel}');
          }
          if (item.damageDescription != null) {
            buf.writeln('     Damage: ${item.damageDescription}');
          }
          if (item.conditionFound != null) {
            buf.writeln('     Condition: ${item.conditionFound}');
          }
        }
        buf.writeln();
      }
    }

    // ── Context cues (important and normal only) ─────────────────────────────
    if (notes != null && notes.isNotEmpty) {
      final visible = notes
          .where((n) => n.priority != CuePriority.ignored)
          .toList()
        ..sort((a, b) {
          if (a.priority == CuePriority.important &&
              b.priority != CuePriority.important) { return -1; }
          if (b.priority == CuePriority.important &&
              a.priority != CuePriority.important) { return 1; }
          return 0;
        });

      if (visible.isNotEmpty) {
        buf.writeln('## CONTEXT CUES & SURVEYOR NOTES');
        for (final note in visible) {
          final priority =
              note.priority == CuePriority.important ? '[IMPORTANT] ' : '';
          final nature =
              note.natureOfContent != null ? '[${note.natureOfContent!.label}] ' : '';
          final lostRelevance = note.hasLostRelevance
              ? ' (lost relevance ${_fmtDate(note.lostRelevanceAt!)})'
              : '';
          buf.writeln('- $priority$nature${note.content}$lostRelevance');
        }
        buf.writeln();
      }
    }

    // ── Repair accounts (invoices + line items) ──────────────────────────────
    if (repairDocuments != null && repairDocuments.isNotEmpty) {
      buf.writeln('## REPAIR ACCOUNTS');
      buf.writeln('Total documents: ${repairDocuments.length}');
      buf.writeln();

      // Summarise financials across all docs
      double totalSubmitted = 0, totalUW = 0, totalOwners = 0;
      for (final d in repairDocuments) {
        totalSubmitted += d.totalIncTax ?? 0;
        totalUW       += d.totalApprovedUW;
        totalOwners   += d.totalApprovedOwners;
      }
      final currency = repairDocuments.first.currency;
      buf.writeln('Total submitted: $currency ${_fmtAmt(totalSubmitted)}');
      buf.writeln('Approved (underwriters): $currency ${_fmtAmt(totalUW)}');
      buf.writeln('Owner\'s account: $currency ${_fmtAmt(totalOwners)}');
      buf.writeln();

      for (final doc in repairDocuments) {
        final docType = doc.documentType.label;
        final supplier = doc.supplierName ?? 'Unknown supplier';
        final docNo = doc.documentNumber != null ? ' No. ${doc.documentNumber}' : '';
        final date = doc.documentDate != null ? ' dated ${_fmtDate(doc.documentDate!)}' : '';
        final total = doc.totalIncTax != null
            ? ' — ${doc.currency} ${_fmtAmt(doc.totalIncTax!)}'
            : '';
        buf.writeln('### $docType$docNo — $supplier$date$total');
        buf.writeln('Status: ${doc.status.label}');
        if (doc.surveyorNotes != null && doc.surveyorNotes!.isNotEmpty) {
          buf.writeln('Surveyor notes: ${doc.surveyorNotes}');
        }
        if (doc.presentationStatement != null &&
            doc.presentationStatement!.isNotEmpty) {
          buf.writeln('Presentation: ${doc.presentationStatement}');
        }

        if (doc.accountLines.isNotEmpty) {
          buf.writeln('Line items:');
          for (final line in doc.accountLines) {
            final desc = line.description ?? '(no description)';
            final nature = line.costNature.label;
            final gross = '${doc.currency} ${_fmtAmt(line.grossAmount)}';
            final status = line.status.label;
            buf.write('  - [$nature] $desc — $gross — $status');
            if (line.underwritersPortion > 0) {
              buf.write(' (UW: ${doc.currency} ${_fmtAmt(line.underwritersPortion)})');
            }
            if (line.ownersPortion > 0) {
              buf.write(' (Owner: ${doc.currency} ${_fmtAmt(line.ownersPortion)})');
            }
            if (line.bettermentDeduction > 0) {
              buf.write(' (Betterment: ${doc.currency} ${_fmtAmt(line.bettermentDeduction)})');
            }
            if (line.apportionmentNotes != null &&
                line.apportionmentNotes!.isNotEmpty) {
              buf.write(' — Note: ${line.apportionmentNotes}');
            }
            buf.writeln();
          }
        }
        buf.writeln();
      }
    }

    // ── Interviews ──────────────────────────────────────────────────────────
    if (interviews != null && interviews.isNotEmpty) {
      buf.writeln('## INTERVIEWS');
      for (final iv in interviews) {
        final who = iv.participants.map((p) => p.displayName).join(', ');
        buf.writeln('### ${iv.displayTitle}  (${_fmtDate(iv.createdAt)})'
            '${who.isNotEmpty ? " — $who" : ""}');
        if (iv.summary != null && iv.summary!.isNotEmpty) {
          buf.writeln('Summary: ${iv.summary}');
        } else if (iv.transcript.isNotEmpty) {
          final excerpt = iv.transcript.length > 600
              ? '${iv.transcript.substring(0, 600)}…'
              : iv.transcript;
          buf.writeln('Transcript excerpt: $excerpt');
        }
        buf.writeln();
      }
    }

    // ── Correspondence ─────────────────────────────────────────────────────
    if (correspondence != null && correspondence.isNotEmpty) {
      buf.writeln('## CORRESPONDENCE');
      for (final c in correspondence) {
        final date = c.corrDate != null ? ' (${_fmtDate(c.corrDate!)})' : '';
        final from = c.sender != null ? ' from ${c.sender}' : '';
        buf.writeln('- ${c.title}$date$from'
            '${c.summary != null && c.summary!.isNotEmpty ? " — ${c.summary}" : ""}');
      }
      buf.writeln();
    }

    // ── General documents ───────────────────────────────────────────────────
    if (documents != null && documents.isNotEmpty) {
      buf.writeln('## DOCUMENTS');
      for (final d in documents) {
        final cat = d.docCategory != null ? '[${d.docCategory!.label}] ' : '';
        final date = d.docDate != null ? ' (${_fmtDate(d.docDate!)})' : '';
        buf.writeln('- $cat${d.title}$date — ${d.availability.label}');
      }
      buf.writeln();
    }

    // ── Photos (captions only) ─────────────────────────────────────────────
    if (photos != null && photos.isNotEmpty) {
      final captioned = photos.where((p) =>
          (p.caption != null && p.caption!.isNotEmpty) ||
          (p.significanceToClaim != null && p.significanceToClaim!.isNotEmpty));
      if (captioned.isNotEmpty) {
        buf.writeln('## PHOTOS');
        for (final p in captioned) {
          final loc = p.locationComponent != null ? '[${p.locationComponent}] ' : '';
          final caption = p.caption ?? '';
          final sig = p.significanceToClaim != null && p.significanceToClaim!.isNotEmpty
              ? ' — ${p.significanceToClaim}'
              : '';
          buf.writeln('- $loc$caption$sig');
        }
        buf.writeln();
      }
    }

    // ── Cost estimate ────────────────────────────────────────────────────────
    if (costEstimateItems != null && costEstimateItems.isNotEmpty) {
      buf.writeln('## COST ESTIMATE');
      double total = 0;
      for (final item in costEstimateItems) {
        total += item.amount;
        buf.writeln('- [${item.category.label}] '
            '${item.description ?? "(no description)"} — ${_fmtAmt(item.amount)}');
      }
      buf.writeln('Total estimate: ${_fmtAmt(total)}');
      buf.writeln();
    }

    return buf.toString().trim();
  }

  static String _fmtAmt(double v) {
    final abs = v.abs();
    final s = abs.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write(',');
      grouped.write(intPart[i]);
    }
    return v < 0 ? '-$grouped.${parts[1]}' : '$grouped.${parts[1]}';
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
