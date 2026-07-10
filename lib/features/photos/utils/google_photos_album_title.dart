// lib/features/photos/utils/google_photos_album_title.dart
//
// Pure composition of the Google Photos album title a survey visit's photos
// are filed under. Kept as a standalone unit-tested function (no LLM, no IO —
// see damage_provider.composeDamageRowDescription for the established
// deterministic-composition style) so the single call site in
// photo_gallery_screen and any future report/export renderer share exactly
// one title format and can never silently drift (see
// reports/utils/section_table_rows.dart for why one-shared-function matters).
//
// Format: "YYYY-MM-DD — <Vessel> — Attendance N"
//   e.g.  "2026-06-28 — MV Surveyor — Attendance 1"
// so the album list in Google Photos reads as a chronological survey diary.

/// Builds the per-visit album title.
///
/// [visitDate] is the attendance date; when null the leading date segment is
/// simply omitted. [vesselName] is the case vessel; blank/null is tolerated
/// and omitted. [attendanceNumber] is the 1-based sequence of the attendance
/// within the case (1 = first visit). When [attendanceNumber] is null the
/// photos are not tied to a specific visit and the title uses an
/// "Unassigned photos" segment instead of "Attendance N".
String googlePhotosAlbumTitle({
  required DateTime? visitDate,
  String? vesselName,
  int? attendanceNumber,
}) {
  final parts = <String>[
    if (visitDate != null) _fmtDate(visitDate),
    if ((vesselName ?? '').trim().isNotEmpty) vesselName!.trim(),
    if (attendanceNumber != null)
      'Attendance $attendanceNumber'
    else
      'Unassigned photos',
  ];
  return parts.join(' — ');
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
