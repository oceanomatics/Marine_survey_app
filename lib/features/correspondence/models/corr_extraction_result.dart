// lib/features/correspondence/models/corr_extraction_result.dart
//
// Typed result of the enriched correspondence AI extraction
// (ClaudeApi.extractCorrespondence / extractCorrespondenceFromText). Each
// sub-item carries enough structure for the correspondence review sheet to
// offer a per-item import switch that routes to the right record. Round-trips
// to/from JSON so a background extraction can be persisted
// (correspondence.pending_extraction) and reviewed later.

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return null;
  return s;
}

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

List<Map<String, dynamic>> _maps(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  return const [];
}

List<String> _strings(dynamic v) {
  if (v is List) {
    return v.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

class CorrParty {
  final String name;
  final String? company;
  final String? role;
  final String? email;
  final String? phone;
  const CorrParty({required this.name, this.company, this.role, this.email, this.phone});

  factory CorrParty.fromJson(Map<String, dynamic> j) => CorrParty(
        name: _s(j['name']) ?? '',
        company: _s(j['company']),
        role: _s(j['role']),
        email: _s(j['email']),
        phone: _s(j['phone']),
      );
  Map<String, dynamic> toJson() =>
      {'name': name, 'company': company, 'role': role, 'email': email, 'phone': phone};
}

class CorrKeyDate {
  final String? date;
  final String description;
  final String kind; // 'event' | 'attendance'
  final String? location;
  const CorrKeyDate({this.date, required this.description, required this.kind, this.location});

  bool get isAttendance => kind.toLowerCase() == 'attendance';

  factory CorrKeyDate.fromJson(dynamic raw) {
    // New format: object. Legacy format: "YYYY-MM-DD — description" string.
    if (raw is Map) {
      final j = raw.cast<String, dynamic>();
      return CorrKeyDate(
        date: _s(j['date']),
        description: _s(j['description']) ?? '',
        kind: (_s(j['kind']) ?? 'event').toLowerCase(),
        location: _s(j['location']),
      );
    }
    final str = raw?.toString() ?? '';
    final parts = str.split('—');
    if (parts.length >= 2) {
      return CorrKeyDate(
          date: _s(parts.first), description: parts.sublist(1).join('—').trim(), kind: 'event');
    }
    return CorrKeyDate(description: str.trim(), kind: 'event');
  }
  Map<String, dynamic> toJson() =>
      {'date': date, 'description': description, 'kind': kind, 'location': location};
}

class CorrFinding {
  final String text;
  final String? caseSection;
  final String? noteCategory;
  const CorrFinding({required this.text, this.caseSection, this.noteCategory});

  factory CorrFinding.fromJson(Map<String, dynamic> j) => CorrFinding(
        text: _s(j['text']) ?? '',
        caseSection: _s(j['case_section']),
        noteCategory: _s(j['note_category']),
      );
  Map<String, dynamic> toJson() =>
      {'text': text, 'case_section': caseSection, 'note_category': noteCategory};
}

class CorrIncident {
  final String title;
  final String? date;
  final String? location;
  final String? description;
  const CorrIncident({required this.title, this.date, this.location, this.description});

  factory CorrIncident.fromJson(Map<String, dynamic> j) => CorrIncident(
        title: _s(j['title']) ?? '',
        date: _s(j['date']),
        location: _s(j['location']),
        description: _s(j['description']),
      );
  Map<String, dynamic> toJson() =>
      {'title': title, 'date': date, 'location': location, 'description': description};
}

class CorrDamage {
  final String description;
  final String? component;
  final String? incidentRef;
  const CorrDamage({required this.description, this.component, this.incidentRef});

  factory CorrDamage.fromJson(Map<String, dynamic> j) => CorrDamage(
        description: _s(j['description']) ?? '',
        component: _s(j['component']),
        incidentRef: _s(j['incident_ref']),
      );
  Map<String, dynamic> toJson() =>
      {'description': description, 'component': component, 'incident_ref': incidentRef};
}

class CorrRepair {
  final String description;
  final String? status;
  final double? estimatedCost;
  final String? incidentRef;
  const CorrRepair({required this.description, this.status, this.estimatedCost, this.incidentRef});

  factory CorrRepair.fromJson(Map<String, dynamic> j) => CorrRepair(
        description: _s(j['description']) ?? '',
        status: _s(j['status']),
        estimatedCost: _d(j['estimated_cost']),
        incidentRef: _s(j['incident_ref']),
      );
  Map<String, dynamic> toJson() => {
        'description': description,
        'status': status,
        'estimated_cost': estimatedCost,
        'incident_ref': incidentRef,
      };
}

class CorrCost {
  final String? category;
  final String description;
  final double? amount;
  final String? currency;
  const CorrCost({this.category, required this.description, this.amount, this.currency});

  factory CorrCost.fromJson(Map<String, dynamic> j) => CorrCost(
        category: _s(j['category']),
        description: _s(j['description']) ?? '',
        amount: _d(j['amount']),
        currency: _s(j['currency']),
      );
  Map<String, dynamic> toJson() =>
      {'category': category, 'description': description, 'amount': amount, 'currency': currency};
}

class CorrExtractionResult {
  final String? summary;
  final String? sender;
  final String? recipient;
  final String? corrDate;
  final String? claimReference;
  final String? vesselName;
  final String? technicalFileNo;
  final String? instructionDate;
  final String? backgroundText;
  final List<CorrParty> parties;
  final List<CorrKeyDate> keyDates;
  final List<CorrFinding> findings;
  final List<CorrIncident> incidents;
  final List<CorrDamage> damage;
  final List<CorrRepair> repairs;
  final List<CorrCost> costs;
  final List<String> actionItems;
  final List<String> decisions;

  const CorrExtractionResult({
    this.summary,
    this.sender,
    this.recipient,
    this.corrDate,
    this.claimReference,
    this.vesselName,
    this.technicalFileNo,
    this.instructionDate,
    this.backgroundText,
    this.parties = const [],
    this.keyDates = const [],
    this.findings = const [],
    this.incidents = const [],
    this.damage = const [],
    this.repairs = const [],
    this.costs = const [],
    this.actionItems = const [],
    this.decisions = const [],
  });

  factory CorrExtractionResult.fromJson(Map<String, dynamic> j) => CorrExtractionResult(
        summary: _s(j['summary']),
        sender: _s(j['sender']),
        recipient: _s(j['recipient']),
        corrDate: _s(j['corr_date']),
        claimReference: _s(j['claim_reference']),
        vesselName: _s(j['vessel_name']),
        technicalFileNo: _s(j['technical_file_no']),
        instructionDate: _s(j['instruction_date']),
        backgroundText: _s(j['background_text']),
        parties: _maps(j['parties']).map(CorrParty.fromJson).where((p) => p.name.isNotEmpty).toList(),
        keyDates: (j['key_dates'] is List)
            ? (j['key_dates'] as List)
                .map(CorrKeyDate.fromJson)
                .where((k) => k.description.isNotEmpty || k.date != null)
                .toList()
            : const [],
        findings:
            _maps(j['context_findings']).map(CorrFinding.fromJson).where((f) => f.text.isNotEmpty).toList(),
        incidents:
            _maps(j['detected_incidents']).map(CorrIncident.fromJson).where((i) => i.title.isNotEmpty).toList(),
        damage: _maps(j['detected_damage'])
            .map(CorrDamage.fromJson)
            .where((d) => d.description.isNotEmpty)
            .toList(),
        repairs: _maps(j['detected_repairs'])
            .map(CorrRepair.fromJson)
            .where((r) => r.description.isNotEmpty)
            .toList(),
        costs: _maps(j['cost_estimates']).map(CorrCost.fromJson).where((c) => c.description.isNotEmpty).toList(),
        actionItems: _strings(j['action_items']),
        decisions: _strings(j['decisions']),
      );

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'sender': sender,
        'recipient': recipient,
        'corr_date': corrDate,
        'claim_reference': claimReference,
        'vessel_name': vesselName,
        'technical_file_no': technicalFileNo,
        'instruction_date': instructionDate,
        'background_text': backgroundText,
        'parties': parties.map((e) => e.toJson()).toList(),
        'key_dates': keyDates.map((e) => e.toJson()).toList(),
        'context_findings': findings.map((e) => e.toJson()).toList(),
        'detected_incidents': incidents.map((e) => e.toJson()).toList(),
        'detected_damage': damage.map((e) => e.toJson()).toList(),
        'detected_repairs': repairs.map((e) => e.toJson()).toList(),
        'cost_estimates': costs.map((e) => e.toJson()).toList(),
        'action_items': actionItems,
        'decisions': decisions,
      };

  /// Header refs that apply to the case/vessel record (reuses the existing
  /// ExtractedCaseRefs seam in the correspondence provider).
  bool get hasHeaderRefs =>
      claimReference != null ||
      technicalFileNo != null ||
      vesselName != null ||
      instructionDate != null;

  /// Nothing worth importing.
  bool get isEmpty =>
      parties.isEmpty &&
      keyDates.isEmpty &&
      findings.isEmpty &&
      incidents.isEmpty &&
      damage.isEmpty &&
      repairs.isEmpty &&
      costs.isEmpty &&
      actionItems.isEmpty &&
      !hasHeaderRefs &&
      backgroundText == null;
}

/// What the surveyor chose to import from a [CorrExtractionResult], by index
/// into the result's per-type lists. Built by the review sheet, consumed by
/// CorrespondenceNotifier.importExtraction.
class CorrImportSelection {
  final bool headerRefs;
  final bool background;
  final Set<int> parties;
  final Set<int> keyDates;
  final Set<int> findings;
  final Set<int> incidents;
  final Set<int> damage;
  final Set<int> repairs;
  final Set<int> costs;
  final Set<int> actionItems;

  const CorrImportSelection({
    required this.headerRefs,
    required this.background,
    required this.parties,
    required this.keyDates,
    required this.findings,
    required this.incidents,
    required this.damage,
    required this.repairs,
    required this.costs,
    required this.actionItems,
  });

  int get count =>
      (headerRefs ? 1 : 0) +
      (background ? 1 : 0) +
      parties.length +
      keyDates.length +
      findings.length +
      incidents.length +
      damage.length +
      repairs.length +
      costs.length +
      actionItems.length;
}
