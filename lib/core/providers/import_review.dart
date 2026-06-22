// lib/core/providers/import_review.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/supabase_client.dart';

@immutable
class ImportReview {
  const ImportReview({
    required this.caseId,
    required this.docTitle,
    required this.importedAt,
    this.occurrenceIds = const <String>[],
    this.damageIds = const <String>[],
    this.repairIds = const <String>[],
    this.attendeeIds = const <String>[],
    this.newAttendanceId,
    this.certificateIds = const <String>[],
    this.machineryIds = const <String>[],
    this.vesselId,
    this.vesselWasCreated = false,
    this.vesselPrevValues = const <String, dynamic>{},
    this.affectedSections = const <String>{},
  });

  final String caseId;
  final String docTitle;
  final DateTime importedAt;

  final List<String> occurrenceIds;
  final List<String> damageIds;
  final List<String> repairIds;
  final List<String> attendeeIds;
  final String? newAttendanceId;
  final List<String> certificateIds;
  final List<String> machineryIds;

  // Vessel revert info
  final String? vesselId;
  final bool vesselWasCreated;
  final Map<String, dynamic> vesselPrevValues; // pre-import field values to restore

  // Which case-home section cards to highlight
  final Set<String> affectedSections;

  String get summaryText {
    final parts = <String>[];
    if (affectedSections.contains('vessel')) parts.add('vessel updated');
    if (occurrenceIds.isNotEmpty) {
      final n = occurrenceIds.length;
      parts.add('$n occurrence${n == 1 ? '' : 's'}');
    }
    if (damageIds.isNotEmpty) {
      final n = damageIds.length;
      parts.add('$n damage item${n == 1 ? '' : 's'}');
    }
    if (attendeeIds.isNotEmpty) {
      final n = attendeeIds.length;
      parts.add('$n attendee${n == 1 ? '' : 's'}');
    }
    if (certificateIds.isNotEmpty) {
      final n = certificateIds.length;
      parts.add('$n certificate${n == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }
}

final importReviewProvider = StateProvider<ImportReview?>((ref) => null);

/// Deletes everything inserted during the import, then restores any modified
/// vessel fields. FK deletion order matters — children before parents.
Future<void> revertImport(ImportReview review, WidgetRef ref) async {
  final client = SupabaseService.client;

  // 1. Attendees (FK → survey_attendances)
  for (final id in review.attendeeIds) {
    try {
      await client.from('attendees').delete().eq('attendee_id', id);
    } catch (_) {}
  }

  // 2. Attendance record (only if it was newly created, not reused)
  if (review.newAttendanceId != null) {
    try {
      await client
          .from('survey_attendances')
          .delete()
          .eq('attendance_id', review.newAttendanceId!);
    } catch (_) {}
  }

  // 3. Repair–damage junction rows before repairs themselves
  for (final id in review.repairIds) {
    try {
      await client
          .from('repair_damage_links')
          .delete()
          .eq('repair_id', id);
    } catch (_) {}
  }

  // 4. Repairs
  for (final id in review.repairIds) {
    try {
      await client.from('repairs').delete().eq('repair_id', id);
    } catch (_) {}
  }

  // 5. Damage items (FK → occurrences)
  for (final id in review.damageIds) {
    try {
      await client.from('damage_items').delete().eq('damage_id', id);
    } catch (_) {}
  }

  // 6. Occurrences
  for (final id in review.occurrenceIds) {
    try {
      await client.from('occurrences').delete().eq('occurrence_id', id);
    } catch (_) {}
  }

  // 7. Certificates
  for (final id in review.certificateIds) {
    try {
      await client.from('certificates').delete().eq('certificate_id', id);
    } catch (_) {}
  }

  // 8. Machinery
  for (final id in review.machineryIds) {
    try {
      await client.from('machinery').delete().eq('machinery_id', id);
    } catch (_) {}
  }

  // 9. Vessel — delete if created, or restore snapshot if it already existed
  if (review.vesselId != null) {
    if (review.vesselWasCreated) {
      try {
        await client
            .from('cases')
            .update({'vessel_id': null})
            .eq('case_id', review.caseId);
        await client
            .from('vessels')
            .delete()
            .eq('vessel_id', review.vesselId!);
      } catch (_) {}
    } else if (review.vesselPrevValues.isNotEmpty) {
      try {
        final toRestore = Map<String, dynamic>.of(review.vesselPrevValues)
          ..remove('vessel_id')
          ..remove('created_at')
          ..remove('updated_at');
        if (toRestore.isNotEmpty) {
          await client
              .from('vessels')
              .update(toRestore)
              .eq('vessel_id', review.vesselId!);
        }
      } catch (_) {}
    }
  }

  ref.read(importReviewProvider.notifier).state = null;
}
