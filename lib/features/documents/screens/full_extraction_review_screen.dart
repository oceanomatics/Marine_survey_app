// lib/features/documents/screens/full_extraction_review_screen.dart
//
// After importing a previous report, shows ALL extracted data
// grouped by section. Surveyor approves or skips each section
// before applying to the case.

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/services/debug_logger.dart';
import '../../../shared/utils/error_handler.dart';
import '../../documents/providers/document_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../survey/providers/damage_provider.dart';
import '../../survey/providers/attendees_provider.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../vessel/providers/certificates_provider.dart';
import '../../../core/api/report_extraction.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/providers/import_review.dart';
import '../../../shared/theme/app_theme.dart';

class FullExtractionReviewScreen extends ConsumerStatefulWidget {
  const FullExtractionReviewScreen({
    super.key,
    required this.caseId,
    required this.doc,
    required this.bytes,
    required this.mimeType,
    this.contextNotes,
  });

  final String caseId;
  final DocumentModel doc;
  final Uint8List bytes;
  final String mimeType;
  final String? contextNotes;

  @override
  ConsumerState<FullExtractionReviewScreen> createState() =>
      _FullExtractionReviewScreenState();
}

class _FullExtractionReviewScreenState
    extends ConsumerState<FullExtractionReviewScreen> {
  bool _extracting = true;
  bool _applying   = false;
  FullReportExtraction? _result;
  String? _error;
  // occurrence_nos already in DB for this case — used to skip duplicates.
  Set<int> _existingOccNos = {};

  // Which sections to apply
  final Set<String> _approved = {
    'vessel', 'machinery', 'occurrences',
    'damage_items', 'repairs_performed', 'attendees', 'certificates',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runExtraction();
    });
  }

  Future<void> _runExtraction() async {
    setState(() { _extracting = true; _error = null; });
    try {
      final base64 = base64Encode(widget.bytes);
      final result = await ReportExtraction.extractFromReport(
        base64Content: base64,
        mediaType: widget.mimeType,
        documentHint: 'marine survey report',
        caseId: widget.caseId,
        contextNotes: widget.contextNotes,
      );
      // Check for existing occurrences so we can warn the user.
      // Failure here is non-fatal — we just won't show the warning.
      Set<int> existingNos = {};
      try {
        final existing = await SupabaseService.client
            .from('occurrences')
            .select('occurrence_no')
            .eq('case_id', widget.caseId);
        existingNos = (existing as List)
            .map((o) => (o['occurrence_no'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
      } catch (_) {}
      setState(() {
        _result = result;
        _existingOccNos = existingNos;
        _extracting = false;
      });
    } catch (e) {
      setState(() { _error = _formatApiError(e); _extracting = false; });
    }
  }

  /// Unpacks DioException into a human-readable string that includes the
  /// HTTP status code and the Anthropic error message from the response body.
  static String _formatApiError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final sb = StringBuffer();
      if (code != null) sb.write('HTTP $code');
      String? msg;
      if (data is Map) {
        msg = (data['error'] as Map?)?['message'] as String?
            ?? data['message'] as String?;
      } else if (data is String && data.isNotEmpty) {
        msg = data.length > 400 ? '${data.substring(0, 400)}…' : data;
      }
      if (msg != null && msg.isNotEmpty) {
        sb.write(code != null ? ' — $msg' : msg);
      } else if (sb.isEmpty) {
        sb.write(e.message ?? e.type.name);
      }
      return sb.toString();
    }
    return e.toString();
  }

  Future<void> _applyToCase() async {
    final result = _result;
    if (result == null) return;
    setState(() => _applying = true);

    // Changelog — collect every ID we insert so the floating review banner
    // can offer a one-tap revert.
    final insOccIds    = <String>[];
    final insDmgIds    = <String>[];
    final insRepIds    = <String>[];
    final insAttIds    = <String>[];
    final insCertIds   = <String>[];
    final insMachIds   = <String>[];
    String? newAttId;            // attendance record created (not reused)
    var vesselSnap     = <String, dynamic>{};
    var vesselCreated  = false;
    final affected     = <String>{};

    try {
      // Fetch current case data upfront — needed for vessel_id, job_number,
      // case_type (used when building the display title at the end).
      final caseRow = await SupabaseService.client
          .from('cases')
          .select('vessel_id, job_number, case_type')
          .eq('case_id', widget.caseId)
          .single();
      String? vesselId = caseRow['vessel_id'] as String?;

      // Snapshot existing vessel fields so we can restore them on revert.
      if (vesselId != null) {
        try {
          final snap = await SupabaseService.client
              .from('vessels')
              .select()
              .eq('vessel_id', vesselId)
              .single();
          vesselSnap = Map<String, dynamic>.from(snap as Map);
        } catch (_) {}
      }
      final jobNumber  = caseRow['job_number']  as String? ?? '';
      final caseType   = caseRow['case_type']   as String? ?? '';

      // ── Vessel particulars ──────────────────────────────────────
      if (_approved.contains('vessel') && result.hasVesselData) {

        // Dump the full raw vessel data from Claude so it's always visible
        // in the VS Code debug console — makes it easy to spot missing fields.
        debugPrint('[VESSEL] raw from Claude: ${jsonEncode(result.vessel)}');

        final vesselFields = <String, dynamic>{};
        const fieldMap = {
          'name': 'name', 'imo_number': 'imo_number',
          'vessel_type': 'vessel_type', 'flag': 'flag',
          'port_of_registry': 'port_of_registry',
          'gross_tonnage': 'gross_tonnage', 'net_tonnage': 'net_tonnage',
          'deadweight': 'deadweight', 'length_oa': 'length_oa',
          'length_bp': 'length_bp', 'breadth': 'breadth',
          'depth': 'depth', 'max_draft': 'max_draft',
          'year_built': 'year_built', 'build_yard': 'build_yard',
          'build_country': 'build_country', 'owners': 'owners',
          'operators': 'operators', 'class_society': 'class_society',
          'class_notation': 'class_notation', 'service_speed': 'service_speed',
        };
        result.vessel.forEach((k, v) {
          if (v != null && v != '' && fieldMap.containsKey(k)) {
            vesselFields[fieldMap[k]!] = v;
          }
        });

        debugPrint('[VESSEL] vesselFields to write: ${jsonEncode(vesselFields)}');

        if (vesselFields.isNotEmpty) {
          final imoNumber =
              (vesselFields['imo_number'] as String? ?? '').trim();

          debugPrint('[VESSEL] case vessel_id=$vesselId  extracted IMO="$imoNumber"');

          if (vesselId == null) {
            // Look for an existing vessel by IMO.
            if (imoNumber.isNotEmpty) {
              debugPrint('[VESSEL] looking up existing vessel by IMO "$imoNumber"');
              final existing = await SupabaseService.client
                  .from('vessels')
                  .select('vessel_id')
                  .eq('imo_number', imoNumber)
                  .maybeSingle();
              vesselId = existing?['vessel_id'] as String?;
              debugPrint('[VESSEL] IMO lookup result: ${vesselId ?? "not found"}');
            }
            if (vesselId != null) {
              // Found by IMO — fetch full snapshot for smart merge + revert.
              try {
                final snap = await SupabaseService.client
                    .from('vessels')
                    .select()
                    .eq('vessel_id', vesselId)
                    .single();
                vesselSnap = Map<String, dynamic>.from(snap as Map);
              } catch (_) {}
              await SupabaseService.client
                  .from('cases')
                  .update({'vessel_id': vesselId})
                  .eq('case_id', widget.caseId);
            }
          }

          if (vesselId != null) {
            debugPrint('[VESSEL] path=smart-merge vesselId=$vesselId');
            // Existing vessel — smart field-by-field merge so we never blindly
            // overwrite more-complete data or change the unique IMO key.
            final merge = _smartMerge(vesselSnap, vesselFields);
            var toUpdate = Map<String, dynamic>.from(merge.toUpdate);

            if (merge.conflicts.isNotEmpty) {
              if (!mounted) return;
              final resolved = await _showConflictDialog(
                merge.conflicts,
                result.reportMeta['report_date'] as String?,
              );
              if (!mounted) return;
              if (resolved == null) return; // User cancelled import.
              toUpdate.addAll(resolved);
            }

            // IMO is a unique key — never update it on an existing vessel.
            toUpdate.remove('imo_number');
            debugPrint('[VESSEL] smart-merge toUpdate keys: ${toUpdate.keys.toList()}');

            if (toUpdate.isNotEmpty) {
              await SupabaseService.client
                  .from('vessels')
                  .update(toUpdate)
                  .eq('vessel_id', vesselId);
            }
          } else {
            // No matching vessel found by IMO lookup — create or reuse one.
            if (imoNumber.isNotEmpty) {
              debugPrint('[VESSEL] path=upsert IMO="$imoNumber"');
              // Upsert on imo_number: atomically inserts a new vessel or
              // updates an existing one if the IMO already exists in the DB
              // (e.g. same vessel imported via a different case).
              // This eliminates 23505 unique constraint violations entirely.
              final vData = await SupabaseService.client
                  .from('vessels')
                  .upsert(vesselFields, onConflict: 'imo_number')
                  .select()
                  .single();
              vesselId = vData['vessel_id'] as String;
              vesselCreated = true;
              debugPrint('[VESSEL] upsert succeeded → vessel_id=$vesselId');
              await DebugLogger.log(
                'Vessel upsert on IMO "$imoNumber" → id $vesselId',
                tag: 'Vessel',
              );
            } else {
              debugPrint('[VESSEL] path=insert (no IMO)');
              // No IMO — plain insert; recover by name if a constraint fires.
              try {
                final vData = await SupabaseService.client
                    .from('vessels')
                    .insert(vesselFields)
                    .select()
                    .single();
                vesselId = vData['vessel_id'] as String;
                vesselCreated = true;
                debugPrint('[VESSEL] insert succeeded → vessel_id=$vesselId');
              } catch (e, st) {
                if (_is23505(e)) {
                  await DebugLogger.log(
                    '23505 on vessel insert (no IMO) — attempting name recovery',
                    tag: 'Vessel',
                    error: e,
                    stack: st,
                  );
                  final vesselName =
                      (vesselFields['name'] as String? ?? '').trim();
                  if (vesselName.isNotEmpty) {
                    final found = await SupabaseService.client
                        .from('vessels')
                        .select('vessel_id')
                        .eq('name', vesselName)
                        .maybeSingle();
                    if (found != null) {
                      vesselId = found['vessel_id'] as String;
                      await DebugLogger.log(
                        'Recovered 23505 by vessel name "$vesselName"',
                        tag: 'Vessel',
                      );
                    } else {
                      rethrow;
                    }
                  } else {
                    rethrow;
                  }
                } else {
                  rethrow;
                }
              }
            }
            await SupabaseService.client
                .from('cases')
                .update({'vessel_id': vesselId})
                .eq('case_id', widget.caseId);
          }

          affected.add('vessel');
        }
      }

      // ── Machinery ────────────────────────────────────────────────
      if (_approved.contains('machinery') &&
          result.hasMachinery && vesselId != null) {
        for (final m in result.machinery) {
          // Skip if same machinery type+make already exists on this vessel.
          final mRole = (m['role'] as String? ?? '').trim();
          final mMake = (m['make'] as String? ?? '').trim();
          if (mRole.isNotEmpty) {
            try {
              final dup = mMake.isNotEmpty
                  ? await SupabaseService.client
                      .from('machinery')
                      .select('machinery_id')
                      .eq('vessel_id', vesselId)
                      .eq('machinery_type', mRole)
                      .eq('make', mMake)
                      .maybeSingle()
                  : await SupabaseService.client
                      .from('machinery')
                      .select('machinery_id')
                      .eq('vessel_id', vesselId)
                      .eq('machinery_type', mRole)
                      .maybeSingle();
              if (dup != null) continue;
            } catch (_) {}
          }
          final machData = await SupabaseService.client.from('machinery').insert({
            'vessel_id':      vesselId,
            'machinery_type': m['role'] ?? 'other',
            'role':           m['role'],
            if (m['make'] != null && m['make'] != '')
              'make': m['make'],
            if (m['model'] != null && m['model'] != '')
              'model': m['model'],
            if (m['quantity'] != null) 'quantity': m['quantity'],
            if (m['mcr_kw'] != null)   'mcr_kw':  m['mcr_kw'],
            if (m['mcr_rpm'] != null)  'mcr_rpm': m['mcr_rpm'],
            if (m['fuel_type'] != null && m['fuel_type'] != '')
              'fuel_type': m['fuel_type'],
            if (m['cylinder_count'] != null)
              'cylinder_count': m['cylinder_count'],
            if (m['configuration'] != null && m['configuration'] != '')
              'configuration': m['configuration'],
            if (m['serial_number'] != null && m['serial_number'] != '')
              'serial_number': m['serial_number'],
          }).select().single();
          insMachIds.add(machData['machinery_id'] as String);
        }
      }

      // itemNoToId tracks item_no → damage_item_id for wiring repairs later.
      final itemNoToId = <int, String>{};

      // ── Occurrences + Damage items ────────────────────────────────
      if (_approved.contains('occurrences') && result.hasOccurrences) {
        // Offset new occurrence numbers so they don't clash with existing ones.
        int occNoOffset = 0;
        try {
          final existingOccs = await SupabaseService.client
              .from('occurrences')
              .select('occurrence_no')
              .eq('case_id', widget.caseId)
              .order('occurrence_no', ascending: false)
              .limit(1);
          if ((existingOccs as List).isNotEmpty) {
            occNoOffset = (existingOccs.first['occurrence_no'] as int?) ?? 0;
          }
        } catch (_) {}

        for (final o in result.occurrences) {
          final occNo = (o['occurrence_no'] as num?)?.toInt() ?? 1;

          // Per-occurrence causation — fall back to global fields if absent.
          final occAllegation =
              ((o['allegation_type'] as String?)?.isNotEmpty == true)
                  ? o['allegation_type'] as String
                  : result.allegationType;
          final occCauseType = (o['cause_type'] as String? ?? '').isNotEmpty
              ? o['cause_type'] as String
              : null;
          final occCauseNarrative =
              ((o['cause_narrative'] as String?) ?? '').isNotEmpty
                  ? o['cause_narrative'] as String
                  : result.causeNarrative.isNotEmpty
                      ? result.causeNarrative
                      : null;

          final occData = await SupabaseService.client
              .from('occurrences')
              .insert({
                'case_id':       widget.caseId,
                'occurrence_no': occNoOffset + occNo,
                if (o['title'] != null && o['title'] != '')
                  'title': o['title'],
                if (o['date_time'] != null && o['date_time'] != '')
                  'date_time': o['date_time'],
                if (o['location'] != null && o['location'] != '')
                  'location': o['location'],
                if (o['brief_description'] != null &&
                    o['brief_description'] != '')
                  'brief_description': o['brief_description'],
                if (o['background_narrative'] != null &&
                    o['background_narrative'] != '')
                  'background_narrative': o['background_narrative'],
                'allegation_type': occAllegation,
                if (occCauseType != null) 'cause_type': occCauseType,
                if (occCauseNarrative != null)
                  'cause_narrative': occCauseNarrative,
              })
              .select()
              .single();

          insOccIds.add(occData['occurrence_id'] as String);
          affected.add('occurrences');

          if (_approved.contains('damage_items') && result.hasDamageItems) {
            final occId = occData['occurrence_id'] as String;
            final items = result.damageItems.where((d) {
              final dn = (d['occurrence_no'] as num?)?.toInt();
              return dn == null || dn == occNo;
            }).toList();
            for (int i = 0; i < items.length; i++) {
              final d = items[i];
              final dmgData = await SupabaseService.client
                  .from('damage_items')
                  .insert({
                    'occurrence_id':  occId,
                    'case_id':        widget.caseId,
                    'component_name': d['component_name'] ?? 'TBC',
                    'sequence_no':    i + 1,
                    if (d['item_no'] != null) 'item_no': d['item_no'],
                    if (d['location_on_vessel'] != null &&
                        d['location_on_vessel'] != '')
                      'location_on_vessel': d['location_on_vessel'],
                    if (d['damage_description'] != null &&
                        d['damage_description'] != '')
                      'damage_description': d['damage_description'],
                    if (d['condition_found'] != null &&
                        d['condition_found'] != '')
                      'condition_found': d['condition_found'],
                    'repair_status': _mapRepairStatus(d['repair_status']),
                    'is_concerning_average': d['is_concerning_average'] ?? true,
                  })
                  .select()
                  .single();
              // Record item_no → UUID for repair wiring.
              final itemNo = (d['item_no'] as num?)?.toInt() ?? (i + 1);
              itemNoToId[itemNo] = dmgData['damage_id'] as String;
              insDmgIds.add(dmgData['damage_id'] as String);
              affected.add('damage');
            }
          }
        }

        // Renumber all case occurrences sequentially by date so the badge
        // numbers are always consistent even when dates from two reports
        // interleave (e.g. Occ 1 from report A is later than Occ 1 from B).
        try {
          final allOccs = await SupabaseService.client
              .from('occurrences')
              .select('occurrence_id, date_time')
              .eq('case_id', widget.caseId);
          final sorted = (allOccs as List).cast<Map<String, dynamic>>()
            ..sort((a, b) {
              final da = a['date_time'] != null
                  ? DateTime.tryParse(a['date_time'] as String)
                  : null;
              final db = b['date_time'] != null
                  ? DateTime.tryParse(b['date_time'] as String)
                  : null;
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });
          // Two-pass renumber avoids unique-constraint (23505) violations when
          // newly inserted occurrences interleave with existing ones by date.
          // Pass 1: park all rows at high temp values to clear any overlaps.
          for (int i = 0; i < sorted.length; i++) {
            await SupabaseService.client
                .from('occurrences')
                .update({'occurrence_no': sorted.length + 1000 + i})
                .eq('occurrence_id', sorted[i]['occurrence_id'] as String);
          }
          // Pass 2: assign final sequential 1-based values.
          for (int i = 0; i < sorted.length; i++) {
            await SupabaseService.client
                .from('occurrences')
                .update({'occurrence_no': i + 1})
                .eq('occurrence_id', sorted[i]['occurrence_id'] as String);
          }
        } catch (e) {
          debugPrint('[FullExtraction] occurrence renumber failed: $e');
        }
      }

      // ── Repairs performed ─────────────────────────────────────────
      if (_approved.contains('repairs_performed') &&
          result.hasRepairsPerformed) {
        for (final r in result.repairsPerformed) {
          final repairData = await SupabaseService.client
              .from('repairs')
              .insert({
                'case_id':    widget.caseId,
                'repair_type': r['repair_type'] ?? 'permanent',
                if (r['description'] != null && r['description'] != '')
                  'description': r['description'],
                if (r['contractor'] != null && r['contractor'] != '')
                  'contractor': r['contractor'],
                if (r['location'] != null && r['location'] != '')
                  'location': r['location'],
                if (r['date_completed'] != null && r['date_completed'] != '')
                  'date_completed': r['date_completed'],
                'status': r['status'] ?? 'completed',
              })
              .select()
              .single();
          final repairId = repairData['repair_id'] as String;
          insRepIds.add(repairId);

          // Wire repair → damage items via junction table.
          final rawNos = r['item_nos'];
          if (rawNos is List) {
            for (final n in rawNos) {
              final itemId = itemNoToId[(n as num).toInt()];
              if (itemId != null) {
                await SupabaseService.client
                    .from('repair_damage_links')
                    .insert({
                  'repair_id': repairId,
                  'damage_id': itemId,
                });
              }
            }
          }
        }
      }

      // ── Attendees ─────────────────────────────────────────────────
      if (_approved.contains('attendees') && result.hasAttendees) {
        // Derive an attendance date from the first extracted occurrence's
        // date, or fall back to today.
        DateTime? attDate;
        if (result.occurrences.isNotEmpty) {
          final raw = result.occurrences.first['date_time'] as String?;
          if (raw != null && raw.isNotEmpty) attDate = DateTime.tryParse(raw);
        }

        // Look for an existing survey_attendance whose date is within
        // 30 days of the report's occurrence date — if found, re-use it
        // so we don't fragment the same visit into multiple records.
        String? attendanceId;
        try {
          final existingAtts = await SupabaseService.client
              .from('survey_attendances')
              .select('attendance_id, attendance_date')
              .eq('case_id', widget.caseId);
          for (final row in existingAtts as List) {
            final rowDate = row['attendance_date'] != null
                ? DateTime.tryParse(row['attendance_date'] as String)
                : null;
            if (attDate != null &&
                rowDate != null &&
                attDate.difference(rowDate).inDays.abs() <= 30) {
              attendanceId = row['attendance_id'] as String;
              break;
            }
          }
        } catch (_) {}

        // No matching attendance found — create a fresh one.
        if (attendanceId == null) {
          try {
            final attRow = await SupabaseService.client
                .from('survey_attendances')
                .insert({
                  'case_id':         widget.caseId,
                  'attendance_type': 'initial',
                  if (attDate != null)
                    'attendance_date':
                        '${attDate.year}-'
                        '${attDate.month.toString().padLeft(2, '0')}-'
                        '${attDate.day.toString().padLeft(2, '0')}',
                })
                .select()
                .single();
            attendanceId = attRow['attendance_id'] as String;
            newAttId = attendanceId; // track as newly created for revert
          } catch (e) {
            debugPrint('[FullExtraction] create attendance failed: $e');
          }
        }

        for (final a in result.attendees) {
          if (a['full_name'] == null || a['full_name'] == '') continue;
          final attData = await SupabaseService.client.from('attendees').insert({
            'case_id':   widget.caseId,
            if (attendanceId != null) 'attendance_id': attendanceId,
            'full_name': a['full_name'],
            if (a['rank_position'] != null && a['rank_position'] != '')
              'rank_position': a['rank_position'],
            if (a['company'] != null && a['company'] != '')
              'company': a['company'],
            if (a['representing'] != null && a['representing'] != '')
              'representing': a['representing'],
            if (a['role_type'] != null)
              'role_type': a['role_type'],
          }).select().single();
          insAttIds.add(attData['attendee_id'] as String);
          affected.add('attendees');
        }
      }

      // ── Certificates ──────────────────────────────────────────────
      if (_approved.contains('certificates') && result.hasCertificates) {
        for (final c in result.certificates) {
          final cType = (c['cert_type'] ?? 'other') as String;
          final cNum  = (c['cert_number'] as String? ?? '').trim();

          // Skip if cert of same type (and number when available) already
          // exists for this case — avoids re-importing the same certificate.
          try {
            final dup = cNum.isNotEmpty
                ? await SupabaseService.client
                    .from('certificates')
                    .select('certificate_id')
                    .eq('case_id', widget.caseId)
                    .eq('cert_type', cType)
                    .eq('cert_number', cNum)
                    .maybeSingle()
                : await SupabaseService.client
                    .from('certificates')
                    .select('certificate_id')
                    .eq('case_id', widget.caseId)
                    .eq('cert_type', cType)
                    .maybeSingle();
            if (dup != null) continue;
          } catch (_) {}

          final certData = await SupabaseService.client
              .from('certificates')
              .insert({
                'case_id':   widget.caseId,
                if (vesselId != null) 'vessel_id': vesselId,
                'cert_type': cType,
                if (c['cert_name'] != null && c['cert_name'] != '')
                  'cert_name': c['cert_name'],
                if (c['issuing_authority'] != null &&
                    c['issuing_authority'] != '')
                  'issuing_authority': c['issuing_authority'],
                if (c['issue_date'] != null && c['issue_date'] != '')
                  'issue_date': c['issue_date'],
                if (c['expiry_date'] != null && c['expiry_date'] != '')
                  'expiry_date': c['expiry_date'],
                if (cNum.isNotEmpty) 'cert_number': cNum,
                'status':         'valid',
                'extracted_auto': true,
                'source_doc_id':  widget.doc.docId,
              })
              .select()
              .single();
          insCertIds.add(certData['certificate_id'] as String);
          affected.add('certificates');
        }
      }

      // ── Case title + claim reference ──────────────────────────────
      {
        final caseUpdate = <String, dynamic>{};

        // Claim reference from report meta (e.g. UCR / QBE reference).
        final claimRef =
            (result.reportMeta['claim_reference'] as String? ?? '').trim();
        if (claimRef.isNotEmpty) caseUpdate['claim_reference'] = claimRef;

        // Build display title: JOB NO – VESSEL – CASE TYPE – OCCURRENCE
        final vName   = (result.vessel['name'] as String? ?? '').trim();
        final typeLabel = _caseTypeLabel(caseType);
        final occTitle = result.occurrences.isNotEmpty
            ? (result.occurrences.first['title'] as String? ?? '').trim()
            : '';
        final parts = [
          if (jobNumber.isNotEmpty) jobNumber,
          if (vName.isNotEmpty)     vName,
          if (typeLabel.isNotEmpty) typeLabel,
          if (occTitle.isNotEmpty)  occTitle,
        ];
        if (parts.isNotEmpty) caseUpdate['title'] = parts.join(' – ');

        if (caseUpdate.isNotEmpty) {
          await SupabaseService.client
              .from('cases')
              .update(caseUpdate)
              .eq('case_id', widget.caseId);
        }
      }

      await SupabaseService.client.from('documents').update({
        'ai_extracted': true,
        'extraction_status': 'completed',
      }).eq('doc_id', widget.doc.docId);

      // Arm the floating review banner so the user can inspect or revert.
      if (affected.isNotEmpty) {
        ref.read(importReviewProvider.notifier).state = ImportReview(
          caseId: widget.caseId,
          docTitle: widget.doc.title,
          importedAt: DateTime.now(),
          occurrenceIds: List.unmodifiable(insOccIds),
          damageIds: List.unmodifiable(insDmgIds),
          repairIds: List.unmodifiable(insRepIds),
          attendeeIds: List.unmodifiable(insAttIds),
          newAttendanceId: newAttId,
          certificateIds: List.unmodifiable(insCertIds),
          machineryIds: List.unmodifiable(insMachIds),
          vesselId: vesselId,
          vesselWasCreated: vesselCreated,
          vesselPrevValues: vesselCreated
              ? const <String, dynamic>{}
              : Map.unmodifiable(vesselSnap),
          affectedSections: Set.unmodifiable(affected),
        );
      }

      // Invalidate every provider that caches data we just wrote so the UI
      // reflects the changes immediately without requiring an app restart.
      ref.invalidate(caseProvider(widget.caseId));
      ref.invalidate(casesProvider);
      ref.invalidate(damageProvider(widget.caseId));
      ref.invalidate(attendeesProvider(widget.caseId));
      ref.invalidate(vesselForCaseProvider(widget.caseId));
      ref.invalidate(certificatesProvider(widget.caseId));
      ref.invalidate(documentProvider(widget.caseId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report data applied to case ✓'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint('[IMPORT] FAILED: $e\n$st');
      if (mounted) showError(context, 'Import failed: $e', error: e, stack: st, tag: 'Import');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  // ── Smart merge helpers ──────────────────────────────────────────────────

  static bool _is23505(Object e) =>
      e.toString().contains('23505') ||
      e.toString().contains('duplicate key value');

  static String _vesselLabel(String key) => const {
    'name':             'Vessel Name',
    'imo_number':       'IMO Number',
    'vessel_type':      'Vessel Type',
    'flag':             'Flag',
    'port_of_registry': 'Port of Registry',
    'gross_tonnage':    'Gross Tonnage (GT)',
    'net_tonnage':      'Net Tonnage (NT)',
    'deadweight':       'Deadweight (DWT)',
    'length_oa':        'Length OA (m)',
    'length_bp':        'Length BP (m)',
    'breadth':          'Breadth (m)',
    'depth':            'Depth (m)',
    'max_draft':        'Max Draft (m)',
    'year_built':       'Year Built',
    'build_yard':       'Build Yard',
    'build_country':    'Build Country',
    'owners':           'Owners',
    'operators':        'Operators',
    'class_society':    'Class Society',
    'class_notation':   'Class Notation',
    'service_speed':    'Service Speed (kn)',
  }[key] ?? key;

  /// Compares extracted vessel fields against the existing DB snapshot.
  ///   • Empty existing  → auto-fill with new value.
  ///   • New is a longer superset of existing → upgrade automatically.
  ///   • Existing is more detailed → keep, skip.
  ///   • Genuinely different → add to conflict list for user decision.
  ///   • IMO number → never auto-changed; always flagged if different.
  static ({Map<String, dynamic> toUpdate, List<_FieldConflict> conflicts})
      _smartMerge(
    Map<String, dynamic> existing,
    Map<String, dynamic> extracted,
  ) {
    final toUpdate  = <String, dynamic>{};
    final conflicts = <_FieldConflict>[];

    final exImo  = existing['imo_number']?.toString().trim() ?? '';
    final newImo = extracted['imo_number']?.toString().trim() ?? '';
    if (exImo.isNotEmpty && newImo.isNotEmpty && exImo != newImo) {
      conflicts.add(_FieldConflict(
        key: 'imo_number', label: 'IMO Number',
        existing: exImo, fromReport: newImo,
      ));
    }

    for (final entry in extracted.entries) {
      if (entry.key == 'imo_number') continue;
      final newVal = entry.value;
      final exVal  = existing[entry.key];

      if (newVal == null || newVal.toString().trim().isEmpty) continue;
      if (exVal  == null || exVal.toString().trim().isEmpty) {
        toUpdate[entry.key] = newVal;
        continue;
      }

      final exStr  = exVal.toString().trim();
      final newStr = newVal.toString().trim();
      if (exStr.toLowerCase() == newStr.toLowerCase()) continue;

      if (newStr.length > exStr.length &&
          newStr.toLowerCase().contains(exStr.toLowerCase())) {
        toUpdate[entry.key] = newVal;
        continue;
      }
      if (exStr.length > newStr.length &&
          exStr.toLowerCase().contains(newStr.toLowerCase())) {
        continue;
      }

      conflicts.add(_FieldConflict(
        key: entry.key, label: _vesselLabel(entry.key),
        existing: exStr, fromReport: newStr,
      ));
    }

    return (toUpdate: toUpdate, conflicts: conflicts);
  }

  Future<Map<String, dynamic>?> _showConflictDialog(
    List<_FieldConflict> conflicts,
    String? reportDate,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConflictDialog(
        conflicts: conflicts,
        reportDate: reportDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Review Extracted Report Data'),
        actions: [
          if (!_extracting && _result != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: _applying ? null : _applyToCase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Apply to Case',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _extracting
          ? _Loading(
              title: widget.doc.title,
              bytes: widget.bytes,
              mimeType: widget.mimeType,
            )
          : _error != null
              ? _Error(error: _error!, onRetry: _runExtraction)
              : _buildReview(),
    );
  }

  Widget _buildReview() {
    final r = _result!;

    // Safety net: if the AI returned nothing parseable, show diagnostics.
    if (r.totalFields == 0) {
      final snippet = r.rawText.isEmpty
          ? '(empty response)'
          : r.rawText.substring(0, r.rawText.length.clamp(0, 800));
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const SizedBox(height: 16),
          const Center(child: Icon(Icons.search_off_outlined,
              color: AppColors.textTertiary, size: 48)),
          const SizedBox(height: 12),
          const Center(child: Text('No data extracted',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary))),
          const SizedBox(height: 8),
          const Center(child: Text(
            'Claude returned a response but no structured data was found. '
            'The raw response is shown below — share it to diagnose the issue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
          )),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              snippet,
              style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: ElevatedButton.icon(
            onPressed: _runExtraction,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          )),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          _SummaryBanner(result: r, doc: widget.doc),
          const SizedBox(height: 16),

          // Duplicate warning
          if (_existingOccNos.isNotEmpty) ...[
            _DupeWarning(existingCount: _existingOccNos.length),
            const SizedBox(height: 8),
          ],

          // Instructions
          const _InfoBox(
            'Select which sections to apply to this case. '
            'You can review and edit details in each module after applying.',
          ),
          const SizedBox(height: 20),

          // Section toggles
          if (r.hasVesselData)
            _SectionToggle(
              key: const ValueKey('vessel'),
              icon: Icons.directions_boat_outlined,
              color: AppColors.teal,
              title: 'Vessel Particulars',
              count: r.vessel.values
                  .where((v) => v != null && v != '')
                  .length,
              unit: 'fields',
              approved: _approved.contains('vessel'),
              onToggle: (v) => setState(() =>
                  v ? _approved.add('vessel') : _approved.remove('vessel')),
              preview: _vesselPreview(r.vessel),
            ),

          if (r.hasMachinery)
            _SectionToggle(
              key: const ValueKey('machinery'),
              icon: Icons.settings_outlined,
              color: AppColors.teal,
              title: 'Machinery',
              count: r.machinery.length,
              unit: 'items',
              approved: _approved.contains('machinery'),
              onToggle: (v) => setState(() => v
                  ? _approved.add('machinery')
                  : _approved.remove('machinery')),
              preview: r.machinery
                  .map((m) =>
                      '${m['quantity'] ?? 1}× ${m['make'] ?? ''} ${m['model'] ?? ''} (${m['role'] ?? ''})')
                  .join('\n'),
            ),

          if (r.hasOccurrences)
            _SectionToggle(
              key: const ValueKey('occurrences'),
              icon: Icons.warning_amber_outlined,
              color: AppColors.coral,
              title: 'Occurrences',
              count: r.occurrences.length,
              unit: 'occurrence${r.occurrences.length == 1 ? '' : 's'}',
              approved: _approved.contains('occurrences'),
              onToggle: (v) => setState(() => v
                  ? _approved.add('occurrences')
                  : _approved.remove('occurrences')),
              preview: r.occurrences
                  .map((o) => o['title'] ?? o['brief_description'] ?? '')
                  .where((s) => s.isNotEmpty)
                  .join('\n'),
            ),

          if (r.hasDamageItems)
            _SectionToggle(
              key: const ValueKey('damage_items'),
              icon: Icons.build_outlined,
              color: AppColors.coral,
              title: 'Damage Items',
              count: r.damageItems.length,
              unit: 'items',
              approved: _approved.contains('damage_items'),
              onToggle: (v) => setState(() => v
                  ? _approved.add('damage_items')
                  : _approved.remove('damage_items')),
              preview: r.damageItems
                  .take(3)
                  .map((d) => '• ${d['component_name'] ?? ''}')
                  .join('\n'),
            ),

          if (r.hasRepairsPerformed)
            _SectionToggle(
              key: const ValueKey('repairs_performed'),
              icon: Icons.handyman_outlined,
              color: AppColors.amber,
              title: 'Repairs Performed',
              count: r.repairsPerformed.length,
              unit: 'repair${r.repairsPerformed.length == 1 ? '' : 's'}',
              approved: _approved.contains('repairs_performed'),
              onToggle: (v) => setState(() => v
                  ? _approved.add('repairs_performed')
                  : _approved.remove('repairs_performed')),
              preview: r.repairsPerformed
                  .take(3)
                  .map((rep) {
                    final type = rep['repair_type'] as String? ?? '';
                    final desc = rep['description'] as String? ?? '';
                    final nos  = (rep['item_nos'] as List?)?.join(', ') ?? '';
                    return '• [${type.toUpperCase()}] $desc'
                        '${nos.isNotEmpty ? ' (items $nos)' : ''}';
                  })
                  .join('\n'),
            ),

          if (r.hasAttendees)
            _SectionToggle(
              key: const ValueKey('attendees'),
              icon: Icons.people_outline,
              color: AppColors.navy,
              title: 'Attendees',
              count: r.attendees.length,
              unit: 'people',
              approved: _approved.contains('attendees'),
              onToggle: (v) => setState(() => v
                  ? _approved.add('attendees')
                  : _approved.remove('attendees')),
              preview: r.attendees
                  .take(4)
                  .map((a) =>
                      '${a['full_name'] ?? ''} — ${a['rank_position'] ?? ''}')
                  .join('\n'),
            ),

          if (r.hasCertificates)
            _SectionToggle(
              key: const ValueKey('certificates'),
              icon: Icons.verified_outlined,
              color: AppColors.purple,
              title: 'Certificates',
              count: r.certificates.length,
              unit: 'certificates',
              approved: _approved.contains('certificates'),
              onToggle: (v) => setState(() => v
                  ? _approved.add('certificates')
                  : _approved.remove('certificates')),
              preview: r.certificates
                  .map((c) =>
                      '${c['cert_name'] ?? c['cert_type'] ?? ''}'
                      '${c['expiry_date'] != null ? ' — expires ${c['expiry_date']}' : ''}')
                  .join('\n'),
            ),

          const SizedBox(height: 20),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applying ? null : _applyToCase,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                _applying
                    ? 'Applying...'
                    : 'Apply ${_approved.length} section${_approved.length == 1 ? '' : 's'} to Case',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _mapRepairStatus(dynamic raw) => const {
        'not_repaired':        'not_started',
        'temporary_repair':    'in_progress',
        'permanently_repaired':'completed',
        'deferred':            'deferred',
        // pass-through values already in DB format
        'not_started':  'not_started',
        'in_progress':  'in_progress',
        'completed':    'completed',
      }[raw as String? ?? ''] ?? 'not_started';

  static String _caseTypeLabel(String value) => const {
        'hm': 'H&M', 'pi': 'P&I', 'cs': 'C&S',
        'dp_trials': 'DP Trials', 'deficiency': 'Deficiency',
        'consulting': 'Consulting',
      }[value] ?? value.toUpperCase();

  String _vesselPreview(Map<String, dynamic> vessel) {
    final parts = <String>[];
    if (vessel['name'] != null && vessel['name'] != '') {
      parts.add(vessel['name'] as String);
    }
    if (vessel['imo_number'] != null && vessel['imo_number'] != '') {
      parts.add('IMO ${vessel['imo_number']}');
    }
    if (vessel['flag'] != null && vessel['flag'] != '') {
      parts.add(vessel['flag'] as String);
    }
    if (vessel['class_society'] != null && vessel['class_society'] != '') {
      parts.add(vessel['class_society'] as String);
    }
    return parts.join(' · ');
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.result, required this.doc});
  final FullReportExtraction result;
  final DocumentModel doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightAmber,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.article_outlined,
              color: AppColors.amber, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            const Text(
              'Previous survey report',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(
              result.totalFields.toString(),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green),
            ),
            const Text('fields',
                style: TextStyle(
                    fontSize: 9,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.unit,
    required this.approved,
    required this.onToggle,
    required this.preview,
  });

  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final String unit;
  final bool approved;
  final ValueChanged<bool> onToggle;
  final String preview;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: approved ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: approved
              ? color.withValues(alpha: 0.3)
              : AppColors.border,
          width: approved ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: approved ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: approved ? color : AppColors.textTertiary,
                    size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: approved
                              ? AppColors.textPrimary
                              : AppColors.textSecondary)),
                  Text('$count $unit found',
                      style: TextStyle(
                          fontSize: 11,
                          color: approved ? color : AppColors.textTertiary)),
                ],
              )),
              Switch(
                value: approved,
                onChanged: onToggle,
                activeThumbColor: color,
              ),
            ]),
            if (approved && preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(preview,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class _DupeWarning extends StatelessWidget {
  const _DupeWarning({required this.existingCount});
  final int existingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This case already has $existingCount occurrence'
              '${existingCount == 1 ? '' : 's'} recorded. '
              'Deselect Occurrences, Damage and Repairs below if you do not '
              'want to add duplicate records.',
              style: const TextStyle(fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.midBlue.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline,
              color: AppColors.midBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.midBlue)),
          ),
        ]),
      );
}

class _Loading extends StatelessWidget {
  const _Loading({
    required this.title,
    required this.bytes,
    required this.mimeType,
  });
  final String title;
  final Uint8List bytes;
  final String mimeType;

  bool get _isImage => mimeType.startsWith('image/');
  bool get _isPdf   => mimeType == 'application/pdf';

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.hardEdge,
            child: _buildPreview(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: AppColors.amber, strokeWidth: 2.5),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Claude is reading "$title"…',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ]);

  Widget _buildPreview() {
    if (_isImage) {
      return InteractiveViewer(
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    }
    if (_isPdf) {
      return PdfViewer.data(
        bytes,
        sourceName: title,
        params: const PdfViewerParams(margin: 4),
      );
    }
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.description_outlined,
            size: 72, color: AppColors.textTertiary),
        SizedBox(height: 12),
        Text('Preview not available for this file type',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      ]),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isAuthError = error.contains('401') || error.contains('authentication');
    final isKeyMissing = error.contains('YOUR_ANTHROPIC_API_KEY');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Icon(
          isAuthError ? Icons.key_off_outlined : Icons.error_outline,
          color: AppColors.error,
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text('Extraction failed',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        // Error detail box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightCoral,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bug_report_outlined,
                    size: 13, color: AppColors.error),
                const SizedBox(width: 6),
                const Text('Error detail',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: error));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 2)),
                    );
                  },
                  child: const Row(children: [
                    Icon(Icons.copy_outlined,
                        size: 12, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Copy',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              SelectableText(
                error,
                style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                    height: 1.5),
              ),
            ],
          ),
        ),

        // Contextual hint for 401 / missing key
        if (isAuthError || isKeyMissing) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A 401 means the Anthropic API key was rejected. '
                    'Check the Usage screen — it shows the last 6 characters '
                    'of the active key. Re-run from VS Code using the Android '
                    'launch config (not a hot restart) to pick up a new key.',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ]),
    );
  }
}

// ── Conflict resolution ────────────────────────────────────────────────────

class _FieldConflict {
  const _FieldConflict({
    required this.key,
    required this.label,
    required this.existing,
    required this.fromReport,
  });
  final String key;
  final String label;
  final String existing;
  final String fromReport;
}

class _ConflictDialog extends StatefulWidget {
  const _ConflictDialog({required this.conflicts, this.reportDate});
  final List<_FieldConflict> conflicts;
  final String? reportDate;

  @override
  State<_ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<_ConflictDialog> {
  late final Map<String, bool> _keepExisting;

  @override
  void initState() {
    super.initState();
    _keepExisting = {for (final c in widget.conflicts) c.key: true};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.compare_arrows, color: AppColors.amber, size: 20),
        SizedBox(width: 8),
        Text('Field conflicts', style: TextStyle(fontSize: 16)),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.reportDate != null &&
                widget.reportDate!.isNotEmpty) ...[
              Text(
                'Report date: ${widget.reportDate}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
            ],
            const Text(
              'These fields differ between the report and current records. '
              'Choose which value to keep for each:',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.conflicts.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 14, color: AppColors.divider),
                itemBuilder: (_, i) {
                  final c = widget.conflicts[i];
                  final keepEx = _keepExisting[c.key] ?? true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        Expanded(
                          child: _ConflictOption(
                            label: 'Current',
                            value: c.existing,
                            selected: keepEx,
                            color: AppColors.midBlue,
                            onTap: () =>
                                setState(() => _keepExisting[c.key] = true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ConflictOption(
                            label: 'Report',
                            value: c.fromReport,
                            selected: !keepEx,
                            color: AppColors.amber,
                            onTap: () =>
                                setState(() => _keepExisting[c.key] = false),
                          ),
                        ),
                      ]),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel import'),
        ),
        ElevatedButton(
          onPressed: () {
            final useFromReport = <String, dynamic>{};
            for (final c in widget.conflicts) {
              if (_keepExisting[c.key] == false) {
                useFromReport[c.key] = c.fromReport;
              }
            }
            Navigator.pop(context, useFromReport);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ConflictOption extends StatelessWidget {
  const _ConflictOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 13,
                color: selected ? color : AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textTertiary,
                  letterSpacing: 0.4,
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
