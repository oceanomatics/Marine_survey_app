// lib/features/reports/utils/certification_narrative.dart
//
// TODO.md §1.8 S5 / C-6f, redesigned 10 July 2026 per surveyor: certificate
// and condition-of-class status is not a mutually-exclusive 3-way pick
// ("all valid" / "some expired" / "not sighted", or "no condition" / "one
// related" / "one not related") — a vessel can carry several statutory
// certificates in different states simultaneously, and several conditions
// of class only some of which relate to the casualty under review. The old
// clause_library-driven 3-way pick silently rendered nothing at all for any
// combination outside its three buckets (e.g. one suspended certificate
// alongside otherwise-valid ones).
//
// Same precedent as composeDamageRowDescription() (damage_provider.dart):
// every input here is already a hard field on the certificate/condition
// models, so a deterministic composed narrative is free, instant, and
// exactly reproducible — nothing for an AI draft to add. Pure functions,
// no Riverpod/Supabase dependency, so they're unit-testable directly.

/// Clause C-6f, composed rather than picked from a fixed set of phrases.
/// Groups [certs] (each a `certificates` row map with `cert_name`/
/// `cert_type`/`status`) by status and narrates every non-empty bucket,
/// instead of requiring the whole set to fit one of three shapes.
String composeStatutoryCertificatesNarrative(List<Map<String, dynamic>> certs) {
  if (certs.isEmpty) return '';

  String nameOf(Map<String, dynamic> c) {
    final name = (c['cert_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return (c['cert_type'] as String?)?.trim().isNotEmpty == true
        ? c['cert_type'] as String
        : 'certificate';
  }

  final byStatus = <String, List<String>>{};
  for (final c in certs) {
    final status = (c['status'] as String?) ?? 'tbc';
    byStatus.putIfAbsent(status, () => []).add(nameOf(c));
  }

  final valid = byStatus['valid'] ?? const [];
  final expired = byStatus['expired'] ?? const [];
  final suspended = byStatus['suspended'] ?? const [];
  final notSighted = byStatus['not_sighted'] ?? const [];
  final tbc = byStatus['tbc'] ?? const [];

  // Common case: every certificate sighted and valid — one clean sentence.
  if (expired.isEmpty && suspended.isEmpty && notSighted.isEmpty && tbc.isEmpty) {
    return 'All statutory certificates were found to be current and valid '
        'at the time of the casualty.';
  }

  String certNoun(List<String> names) =>
      names.length == 1 ? 'certificate' : 'certificates';
  String wasWere(List<String> names) => names.length == 1 ? 'was' : 'were';

  final parts = <String>[];
  if (notSighted.isNotEmpty) {
    parts.add('Copies of the following statutory ${certNoun(notSighted)} '
        '${wasWere(notSighted)} not made available to the Undersigned for '
        'review: ${notSighted.join(', ')}.');
  }
  if (expired.isNotEmpty) {
    parts.add('The following statutory ${certNoun(expired)} '
        '${wasWere(expired)} noted as expired at the time of the casualty: '
        '${expired.join(', ')}.');
  }
  if (suspended.isNotEmpty) {
    parts.add('The following statutory ${certNoun(suspended)} '
        '${wasWere(suspended)} noted as suspended: ${suspended.join(', ')}.');
  }
  if (tbc.isNotEmpty) {
    parts.add('The status of the following statutory ${certNoun(tbc)} had '
        'not been confirmed at the time of writing: ${tbc.join(', ')}.');
  }
  if (valid.isNotEmpty) {
    parts.add('The remaining statutory ${certNoun(valid)} — '
        '${valid.join(', ')} — ${wasWere(valid)} confirmed current and '
        'valid.');
  }
  return parts.join(' ');
}

/// Condition-of-class narrative, composed from the actual count of
/// [conditions] (each a `class_conditions` row map with
/// `occurrence_related`) rather than a fixed "none / one related / one not
/// related" pick. Deliberately doesn't restate the class society itself —
/// clause C-6a (`class_status_statement`, `_buildClassStatutoryText`)
/// already covers that immediately above wherever this is used, in the
/// current report layout.
///
/// Note: `class_conditions` has no closed/satisfied status field, so this
/// can only speak to whether a condition has been *issued*, not whether it
/// remains outstanding — "issued" is used throughout rather than
/// "outstanding"/"current" to avoid overclaiming what the data supports.
String composeConditionOfClassNarrative(List<Map<String, dynamic>> conditions) {
  if (conditions.isEmpty) {
    return 'No condition of class has been issued against the vessel at '
        'the time of this survey.';
  }

  final total = conditions.length;
  final related =
      conditions.where((c) => c['occurrence_related'] == true).length;
  final notRelated = total - related;

  final countPhrase =
      total == 1 ? '1 condition of class has' : '$total conditions of class have';
  final buf =
      StringBuffer('$countPhrase been issued against the vessel');

  if (related == 0) {
    buf.write(total == 1
        ? ', which is not considered related to the casualty under review'
        : ', none of which are considered related to the casualty under review');
  } else if (related == total) {
    buf.write(total == 1
        ? ', which is considered related to the casualty under review'
        : ', all of which are considered related to the casualty under review');
  } else {
    final relPhrase = related == 1 ? '1 is' : '$related are';
    final notRelPhrase = notRelated == 1 ? '1 is' : '$notRelated are';
    buf.write(', of which $relPhrase considered related to the casualty '
        'under review and $notRelPhrase not');
  }
  buf.write('. Details are set out below.');
  return buf.toString();
}
