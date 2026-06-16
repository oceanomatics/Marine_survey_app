// lib/features/documents/screens/full_extraction_review_screen.dart
//
// After importing a previous report, shows ALL extracted data
// grouped by section. Surveyor approves or skips each section
// before applying to the case.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../documents/providers/document_provider.dart';
import '../../../core/api/report_extraction.dart';
import '../../../core/api/supabase_client.dart';
import '../../../shared/theme/app_theme.dart';

class FullExtractionReviewScreen extends ConsumerStatefulWidget {
  const FullExtractionReviewScreen({
    super.key,
    required this.caseId,
    required this.doc,
    required this.bytes,
    required this.mimeType,
  });

  final String caseId;
  final DocumentModel doc;
  final Uint8List bytes;
  final String mimeType;

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

  // Which sections to apply
  final Set<String> _approved = {
    'vessel', 'machinery', 'occurrences',
    'damage_items', 'attendees', 'certificates',
  };

  @override
  void initState() {
    super.initState();
    _runExtraction();
  }

  Future<void> _runExtraction() async {
    setState(() { _extracting = true; _error = null; });
    try {
      final base64 = base64Encode(widget.bytes);
      final result = await ReportExtraction.extractFromReport(
        base64Content: base64,
        mediaType: widget.mimeType,
        documentHint: 'marine survey report',
      );
      setState(() { _result = result; _extracting = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _extracting = false; });
    }
  }

  Future<void> _applyToCase() async {
    final result = _result;
    if (result == null) return;
    setState(() => _applying = true);

    try {
      // ── Vessel particulars ──────────────────────────────────────
      if (_approved.contains('vessel') && result.hasVesselData) {
        // Get or create vessel
        final caseData = await SupabaseService.client
            .from('cases')
            .select('vessel_id')
            .eq('case_id', widget.caseId)
            .single();
        String? vesselId = caseData['vessel_id'] as String?;

        final vesselFields = <String, dynamic>{};
        final fieldMap = {
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

        if (vesselFields.isNotEmpty) {
          if (vesselId == null) {
            final vData = await SupabaseService.client
                .from('vessels')
                .insert(vesselFields)
                .select()
                .single();
            vesselId = vData['vessel_id'] as String;
            await SupabaseService.client
                .from('cases')
                .update({'vessel_id': vesselId})
                .eq('case_id', widget.caseId);
          } else {
            await SupabaseService.client
                .from('vessels')
                .update(vesselFields)
                .eq('vessel_id', vesselId);
          }
        }

        // ── Machinery ─────────────────────────────────────────────
        if (_approved.contains('machinery') &&
            result.hasMachinery && vesselId != null) {
          for (final m in result.machinery) {
            await SupabaseService.client.from('machinery').insert({
              'vessel_id':    vesselId,
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
            });
          }
        }

        // ── Occurrences ──────────────────────────────────────────
        if (_approved.contains('occurrences') && result.hasOccurrences) {
          for (final o in result.occurrences) {
            final occData = await SupabaseService.client
                .from('occurrences')
                .insert({
                  'case_id':       widget.caseId,
                  'occurrence_no': o['occurrence_no'] ?? 1,
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
                  'allegation_type': result.allegationType,
                  if (result.causeNarrative.isNotEmpty)
                    'cause_narrative': result.causeNarrative,
                })
                .select()
                .single();

            // ── Damage items linked to this occurrence ─────────────
            if (_approved.contains('damage_items') &&
                result.hasDamageItems) {
              final occId = occData['occurrence_id'] as String;
              for (int i = 0; i < result.damageItems.length; i++) {
                final d = result.damageItems[i];
                await SupabaseService.client
                    .from('damage_items')
                    .insert({
                      'occurrence_id':  occId,
                      'case_id':        widget.caseId,
                      'component_name': d['component_name'] ?? 'TBC',
                      'sequence_no':    i + 1,
                      if (d['location_on_vessel'] != null &&
                          d['location_on_vessel'] != '')
                        'location_on_vessel': d['location_on_vessel'],
                      if (d['damage_description'] != null &&
                          d['damage_description'] != '')
                        'damage_description': d['damage_description'],
                      if (d['condition_found'] != null &&
                          d['condition_found'] != '')
                        'condition_found': d['condition_found'],
                      if (d['repair_type'] != null)
                        'repair_type': d['repair_type'],
                      'repair_status':
                          d['repair_status'] ?? 'not_started',
                      'is_concerning_average':
                          d['is_concerning_average'] ?? true,
                    });
              }
            }
          }
        }

        // ── Attendees ────────────────────────────────────────────
        if (_approved.contains('attendees') && result.hasAttendees) {
          for (final a in result.attendees) {
            if (a['full_name'] == null || a['full_name'] == '') continue;
            await SupabaseService.client.from('attendees').insert({
              'case_id':   widget.caseId,
              'full_name': a['full_name'],
              if (a['rank_position'] != null && a['rank_position'] != '')
                'rank_position': a['rank_position'],
              if (a['company'] != null && a['company'] != '')
                'company': a['company'],
              if (a['representing'] != null && a['representing'] != '')
                'representing': a['representing'],
              if (a['role_type'] != null)
                'role_type': a['role_type'],
            });
          }
        }

        // ── Certificates ─────────────────────────────────────────
        if (_approved.contains('certificates') && result.hasCertificates) {
          for (final c in result.certificates) {
            await SupabaseService.client.from('certificates').insert({
              'case_id':  widget.caseId,
              if (vesselId != null) 'vessel_id': vesselId,
              'cert_type': c['cert_type'] ?? 'other',
              if (c['cert_name'] != null && c['cert_name'] != '')
                'cert_name': c['cert_name'],
              if (c['issuing_authority'] != null &&
                  c['issuing_authority'] != '')
                'issuing_authority': c['issuing_authority'],
              if (c['issue_date'] != null && c['issue_date'] != '')
                'issue_date': c['issue_date'],
              if (c['expiry_date'] != null && c['expiry_date'] != '')
                'expiry_date': c['expiry_date'],
              if (c['cert_number'] != null && c['cert_number'] != '')
                'cert_number': c['cert_number'],
              'status':         'valid',
              'extracted_auto': true,
              'source_doc_id':  widget.doc.docId,
            });
          }
        }
      }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
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
          ? _Loading(title: widget.doc.title)
          : _error != null
              ? _Error(error: _error!, onRetry: _runExtraction)
              : _buildReview(),
    );
  }

  Widget _buildReview() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          _SummaryBanner(result: r, doc: widget.doc),
          const SizedBox(height: 16),

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
  const _Loading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                  color: AppColors.amber, strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            const Text('Analysing report...',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            const Text(
              'Claude is reading the report and extracting\nvessel data, damage items, attendees\nand certificates...',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textTertiary),
            ),
          ]),
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text('Extraction failed',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ]),
        ),
      );
}
