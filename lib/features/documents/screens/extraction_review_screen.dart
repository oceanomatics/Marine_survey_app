// lib/features/documents/screens/extraction_review_screen.dart
//
// After importing a document, Claude extracts all fields.
// This screen shows what was found and lets the surveyor
// confirm or correct each field before applying to the case.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/document_provider.dart';
import '../../../core/api/supabase_client.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../../shared/theme/app_theme.dart';

class ExtractionReviewScreen extends ConsumerStatefulWidget {
  const ExtractionReviewScreen({
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
  ConsumerState<ExtractionReviewScreen> createState() =>
      _ExtractionReviewScreenState();
}

class _ExtractionReviewScreenState
    extends ConsumerState<ExtractionReviewScreen> {
  bool _extracting = true;
  bool _applying = false;
  ExtractionResult? _result;
  String? _error;

  // Editable controllers for vessel fields
  final Map<String, TextEditingController> _vesselCtrls = {};
  // Editable controllers for cert fields
  final Map<String, TextEditingController> _certCtrls = {};

  // Which fields the surveyor has approved
  final Set<String> _approvedVessel = {};
  final Set<String> _approvedCert = {};

  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so Riverpod notifiers are safe to read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runExtraction();
    });
  }

  @override
  void dispose() {
    for (final c in [..._vesselCtrls.values, ..._certCtrls.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _runExtraction() async {
    setState(() {
      _extracting = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(extractionProvider.notifier).extractFromImage(
                docId: widget.doc.docId,
                bytes: widget.bytes,
                mimeType: widget.mimeType,
                documentHint: widget.doc.docCategory?.label,
              );

      if (result != null) {
        _initControllers(result);
        setState(() {
          _result = result;
          _extracting = false;
        });
      } else {
        setState(() {
          _error = 'Extraction failed. You can still fill in details manually.';
          _extracting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _extracting = false;
      });
    }
  }

  void _initControllers(ExtractionResult result) {
    // Vessel fields
    final vesselLabels = {
      'name': 'Vessel Name',
      'imo_number': 'IMO Number',
      'vessel_type': 'Vessel Type',
      'flag': 'Flag',
      'port_of_registry': 'Port of Registry',
      'gross_tonnage': 'Gross Tonnage',
      'net_tonnage': 'Net Tonnage',
      'deadweight': 'Deadweight',
      'length_oa': 'Length OA (m)',
      'length_bp': 'Length BP (m)',
      'breadth': 'Breadth (m)',
      'depth': 'Depth (m)',
      'max_draft': 'Max Draft (m)',
      'year_built': 'Year Built',
      'build_yard': 'Build Yard',
      'build_country': 'Build Country',
      'owners': 'Owners',
      'operators': 'Operators',
      'class_society': 'Class Society',
      'class_notation': 'Class Notation',
      'service_speed': 'Service Speed (kts)',
    };
    for (final entry in vesselLabels.entries) {
      final val = result.vesselFields[entry.key];
      if (val != null) {
        _vesselCtrls[entry.key] = TextEditingController(text: val.toString());
        _approvedVessel.add(entry.key); // pre-approve all extracted
      }
    }

    // Certificate fields
    final certLabels = {
      'cert_name': 'Certificate Name',
      'issuing_authority': 'Issuing Authority',
      'issue_date': 'Issue Date',
      'expiry_date': 'Expiry Date',
      'annual_survey_date': 'Annual Survey Date',
      'cert_number': 'Certificate Number',
    };
    for (final entry in certLabels.entries) {
      final val = result.certFields[entry.key];
      if (val != null) {
        _certCtrls[entry.key] = TextEditingController(text: val.toString());
        _approvedCert.add(entry.key);
      }
    }
  }

  Future<void> _applyToCase() async {
    setState(() => _applying = true);
    try {
      final vesselNotifier =
          ref.read(vesselForCaseProvider(widget.caseId).notifier);
      final vesselAsync = ref.read(vesselForCaseProvider(widget.caseId));

      // Build approved vessel fields from controllers
      final vesselFields = <String, dynamic>{};
      for (final key in _approvedVessel) {
        final ctrl = _vesselCtrls[key];
        if (ctrl != null && ctrl.text.trim().isNotEmpty) {
          final raw = ctrl.text.trim();
          // Try numeric parse for numeric fields
          final numericFields = {
            'gross_tonnage',
            'net_tonnage',
            'deadweight',
            'length_oa',
            'length_bp',
            'breadth',
            'depth',
            'max_draft',
            'service_speed'
          };
          final intFields = {'year_built'};
          if (numericFields.contains(key)) {
            vesselFields[key] = double.tryParse(raw) ?? raw;
          } else if (intFields.contains(key)) {
            vesselFields[key] = int.tryParse(raw) ?? raw;
          } else {
            vesselFields[key] = raw;
          }
        }
      }

      // Save vessel fields
      if (vesselFields.isNotEmpty) {
        final vessel = vesselAsync.value;
        if (vessel != null) {
          await vesselNotifier.saveVessel(
              vesselId: vessel.vesselId, fields: vesselFields);
        } else {
          // Create vessel first
          final name = vesselFields['name'] as String? ?? 'TBC';
          final created = await vesselNotifier.createVessel(
              caseId: widget.caseId, name: name);
          await vesselNotifier.saveVessel(
              vesselId: created.vesselId, fields: vesselFields);
        }
      }

      // Save certificate record
      if (_approvedCert.isNotEmpty) {
        final certFields = <String, dynamic>{
          'case_id': widget.caseId,
          'source_doc_id': widget.doc.docId,
          'extracted_auto': true,
          'status': 'valid',
        };
        final vesselId =
            ref.read(vesselForCaseProvider(widget.caseId)).value?.vesselId;
        if (vesselId != null) certFields['vessel_id'] = vesselId;

        if (_result != null) {
          certFields['cert_type'] = _result!.certFields['cert_type'] ?? 'other';
        }
        for (final key in _approvedCert) {
          final ctrl = _certCtrls[key];
          if (ctrl != null && ctrl.text.trim().isNotEmpty) {
            certFields[key] = ctrl.text.trim();
          }
        }

        await SupabaseService.client.from('certificates').insert(certFields);
      }

      // Auto-rename the document with a meaningful title derived from the
      // extracted cert name and vessel name (e.g. "Class Certificate — MV Test").
      final certName   = _certCtrls['cert_name']?.text.trim() ?? '';
      final vesselName = _vesselCtrls['name']?.text.trim() ?? '';
      final autoTitle  = [
        if (certName.isNotEmpty)   certName,
        if (vesselName.isNotEmpty) vesselName,
      ].join(' — ');
      if (autoTitle.isNotEmpty && autoTitle != widget.doc.title) {
        try {
          await SupabaseService.client
              .from('documents')
              .update({'title': autoTitle})
              .eq('doc_id', widget.doc.docId);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data applied to case ✓'),
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
              content: Text('Error applying data: $e'),
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
        title: const Text('Review Extracted Data'),
        actions: [
          if (!_extracting && _result != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: _applying ? null : _applyToCase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
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
          ? _ExtractionLoading(docTitle: widget.doc.title)
          : _error != null && _result == null
              ? _ExtractionError(
                  error: _error!,
                  onRetry: _runExtraction,
                )
              : _buildReview(),
    );
  }

  Widget _buildReview() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document identity banner
          _DocumentBanner(doc: widget.doc, result: result),
          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.midBlue.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: AppColors.midBlue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review each field before applying',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.midBlue),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Uncheck any field you want to exclude. '
                      'Edit values directly if Claude misread anything. '
                      'Tap Apply to Case when ready.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.midBlue.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Vessel fields section
          if (_vesselCtrls.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.directions_boat_outlined,
              label: 'Vessel Particulars',
              color: AppColors.teal,
              approvedCount: _approvedVessel.length,
              totalCount: _vesselCtrls.length,
            ),
            const SizedBox(height: 10),
            ..._vesselCtrls.entries.map((entry) => _FieldRow(
                  fieldKey: entry.key,
                  controller: entry.value,
                  approved: _approvedVessel.contains(entry.key),
                  onToggle: (v) => setState(() {
                    if (v) {
                      _approvedVessel.add(entry.key);
                    } else {
                      _approvedVessel.remove(entry.key);
                    }
                  }),
                )),
            const SizedBox(height: 20),
          ],

          // Certificate fields section
          if (_certCtrls.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.verified_outlined,
              label: 'Certificate Record',
              color: AppColors.purple,
              approvedCount: _approvedCert.length,
              totalCount: _certCtrls.length,
            ),
            const SizedBox(height: 10),
            ..._certCtrls.entries.map((entry) => _FieldRow(
                  fieldKey: entry.key,
                  controller: entry.value,
                  approved: _approvedCert.contains(entry.key),
                  onToggle: (v) => setState(() {
                    if (v) {
                      _approvedCert.add(entry.key);
                    } else {
                      _approvedCert.remove(entry.key);
                    }
                  }),
                )),
            const SizedBox(height: 20),
          ],

          if (_vesselCtrls.isEmpty && _certCtrls.isEmpty)
            const _NoFieldsFound(),

          // Apply button at bottom
          if (_result != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _applying ? null : _applyToCase,
                icon: const Icon(Icons.check_circle_outline),
                label: _applying
                    ? const Text('Applying...')
                    : Text(
                        'Apply ${_approvedVessel.length + _approvedCert.length}'
                        ' field${(_approvedVessel.length + _approvedCert.length) == 1 ? '' : 's'} to Case',
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
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _ExtractionLoading extends StatelessWidget {
  const _ExtractionLoading({required this.docTitle});
  final String docTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
                color: AppColors.amber, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          const Text('Analysing document...',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            docTitle,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Claude is reading the document\nand extracting vessel data...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ]),
      ),
    );
  }
}

class _ExtractionError extends StatelessWidget {
  const _ExtractionError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          const Text('Extraction failed',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
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
}

class _DocumentBanner extends StatelessWidget {
  const _DocumentBanner({required this.doc, required this.result});
  final DocumentModel doc;
  final ExtractionResult result;

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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightAmber,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description_outlined,
              color: AppColors.amber, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            if (result.documentType != null)
              Text(result.documentType!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ],
        )),
        // Extraction summary badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(
              '${result.vesselFields.length + result.certFields.length}',
              style: const TextStyle(
                  fontSize: 18,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
    required this.approvedCount,
    required this.totalCount,
  });
  final IconData icon;
  final String label;
  final Color color;
  final int approvedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      const Spacer(),
      Text('$approvedCount / $totalCount selected',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}

class _FieldRow extends StatefulWidget {
  const _FieldRow({
    required this.fieldKey,
    required this.controller,
    required this.approved,
    required this.onToggle,
  });
  final String fieldKey;
  final TextEditingController controller;
  final bool approved;
  final ValueChanged<bool> onToggle;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  static const _labels = {
    'name': 'Vessel Name',
    'imo_number': 'IMO Number',
    'vessel_type': 'Type',
    'flag': 'Flag',
    'port_of_registry': 'Port of Registry',
    'gross_tonnage': 'Gross Tonnage',
    'net_tonnage': 'Net Tonnage',
    'deadweight': 'DWT (tonnes)',
    'length_oa': 'Length OA (m)',
    'length_bp': 'Length BP (m)',
    'breadth': 'Breadth (m)',
    'depth': 'Depth (m)',
    'max_draft': 'Max Draft (m)',
    'year_built': 'Year Built',
    'build_yard': 'Build Yard',
    'build_country': 'Build Country',
    'owners': 'Owners',
    'operators': 'Operators',
    'class_society': 'Class Society',
    'class_notation': 'Class Notation',
    'service_speed': 'Service Speed (kts)',
    'cert_name': 'Certificate',
    'issuing_authority': 'Issuing Authority',
    'issue_date': 'Issue Date',
    'expiry_date': 'Expiry Date',
    'annual_survey_date': 'Annual Survey Date',
    'cert_number': 'Certificate Number',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[widget.fieldKey] ?? widget.fieldKey;
    final approved = widget.approved;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: approved ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: approved
              ? AppColors.midBlue.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(children: [
        // Approve checkbox
        Checkbox(
          value: approved,
          onChanged: (v) => widget.onToggle(v ?? false),
          activeColor: AppColors.midBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        // Label
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  approved ? AppColors.textSecondary : AppColors.textTertiary,
            ),
          ),
        ),
        // Editable value
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: widget.controller,
              enabled: approved,
              style: TextStyle(
                fontSize: 13,
                color:
                    approved ? AppColors.textPrimary : AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NoFieldsFound extends StatelessWidget {
  const _NoFieldsFound();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightAmber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(children: [
        Icon(Icons.warning_amber_outlined, color: AppColors.amber, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'No structured data could be extracted. '
            'The document may be handwritten, low resolution, '
            'or in an unsupported format. You can still file it in the vault.',
            style: TextStyle(fontSize: 12, color: AppColors.amber),
          ),
        ),
      ]),
    );
  }
}
