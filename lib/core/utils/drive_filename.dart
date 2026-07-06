// lib/core/utils/drive_filename.dart
//
// Builds human-readable Drive filenames instead of raw UUIDs — e.g.
// "2026-07-06 - John Smith - Re Survey Report.eml" instead of
// "00e6ba92-1a2b-4c3d-....eml". Drive itself allows almost any character in
// a filename, but this also strips the handful of characters that break on
// Windows (relevant once synced via Google Drive for Desktop) and collapses
// whitespace — while deliberately keeping spaces/hyphens/parens etc. for
// readability, unlike the more aggressive underscore-based sanitizer used
// for Supabase Storage paths (see document_provider.dart's
// _sanitizeFilename, which targets machine paths, not human-facing names).

/// Joins non-empty [parts] with " - ", appends [extension], and strips
/// characters that are invalid in Drive/Windows filenames.
String buildDriveFilename(List<String?> parts, String extension) {
  final cleaned = parts
      .where((p) => p != null && p.trim().isNotEmpty)
      .map((p) => _sanitizePart(p!.trim()))
      .where((p) => p.isNotEmpty)
      .toList();
  final base = cleaned.isEmpty ? 'Untitled' : cleaned.join(' - ');
  // Comfortably under filesystem limits (255 bytes) even with a long
  // subject/caption; Drive itself has no meaningful practical limit.
  final truncated = base.length > 150 ? base.substring(0, 150).trim() : base;
  return '$truncated.$extension';
}

String _sanitizePart(String s) => s
    .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
