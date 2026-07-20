// lib/features/cases/screens/edit_case_screen.dart
//
// Standalone case-details editor. Replaces the old modal bottom sheet.
// Opened via /cases/:caseId/edit. Saves via caseProvider then pops back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cases_provider.dart';
import '../models/case_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../settings/providers/organisations_provider.dart';
import '../../../shared/widgets/app_feedback.dart';

const _kCurrencies = [
  'AUD', 'USD', 'GBP', 'EUR', 'SGD', 'NZD',
  'JPY', 'HKD', 'AED', 'NOK', 'DKK', 'SEK',
];

class EditCaseScreen extends ConsumerStatefulWidget {
  const EditCaseScreen({super.key, required this.caseId});
  final String caseId;

  @override
  ConsumerState<EditCaseScreen> createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends ConsumerState<EditCaseScreen> {
  late final TextEditingController _jobCtrl;
  late final TextEditingController _claimCtrl;
  late final TextEditingController _instructingPartyCtrl;
  late final TextEditingController _assuredCtrl;
  DateTime? _instructionDate;
  CaseStatus? _status;
  CaseType? _caseType;
  OutputFormat? _outputFormat;
  String? _organisationId;
  String? _baseCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = ref.read(caseProvider(widget.caseId)).value;
    _jobCtrl              = TextEditingController(
        text: c?.hasPlaceholderFileNo == true ? '' : (c?.technicalFileNo ?? ''));
    _claimCtrl            = TextEditingController(text: c?.claimReference ?? '');
    _instructingPartyCtrl = TextEditingController(text: c?.instructingParty ?? '');
    _assuredCtrl          = TextEditingController(text: c?.assured ?? '');
    _instructionDate      = c?.instructionDate;
    _status               = c?.status;
    _caseType             = c?.caseType;
    _outputFormat         = c?.outputFormat;
    _organisationId       = c?.organisationId;
    _baseCurrency         = c?.baseCurrency;
  }

  @override
  void dispose() {
    _jobCtrl.dispose();
    _claimCtrl.dispose();
    _instructingPartyCtrl.dispose();
    _assuredCtrl.dispose();
    super.dispose();
  }

  String? _v(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rawJob = _v(_jobCtrl);
      await ref.read(caseProvider(widget.caseId).notifier).updateCaseRefs(
        technicalFileNo: rawJob ?? 'TMP-${DateTime.now().millisecondsSinceEpoch}',
        claimReference:  _v(_claimCtrl),
        status:          _status,
        caseType:        _caseType,
        instructionDate: _instructionDate,
        outputFormat:    _outputFormat,
        organisationId:  _organisationId,
        baseCurrency:    _baseCurrency,
        instructingParty: _v(_instructingPartyCtrl),
        assured:         _v(_assuredCtrl),
      );
      if (mounted) {
        showSavedToast(context);
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Case Details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      // Pinned save button — stays visible while scrolling the form
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── References ──────────────────────────────────────────────
            _sectionLabel('References'),
            const SizedBox(height: 10),
            _field('Job / File Number', _jobCtrl, hint: 'e.g. AU-M53-056789'),
            const SizedBox(height: 10),
            _field('Claim Reference', _claimCtrl,
                hint: 'e.g. GARD-2025-0123456'),
            const SizedBox(height: 10),

            // Instruction date
            _datePicker(
              label: 'Instruction Date',
              icon: Icons.calendar_today_outlined,
              value: _instructionDate,
              onPicked: (d) => setState(() => _instructionDate = d),
              onCleared: () => setState(() => _instructionDate = null),
            ),
            const SizedBox(height: 16),

            // ── Survey Classification ────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            _sectionLabel('Survey Classification'),
            const SizedBox(height: 10),

            DropdownButtonFormField<CaseType>(
              initialValue: _caseType,
              decoration: _inputDeco('Survey Type'),
              items: CaseType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _caseType = v),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<CaseStatus>(
              initialValue: _status,
              decoration: _inputDeco('Status'),
              items: CaseStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<OutputFormat>(
              initialValue: _outputFormat,
              decoration: _inputDeco('Report Format'),
              items: OutputFormat.values
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.label,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _outputFormat = v),
            ),
            const SizedBox(height: 16),

            // ── Survey Parties ───────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            _sectionLabel('Survey Parties'),
            const SizedBox(height: 10),

            _field('Instructing Party', _instructingPartyCtrl,
                hint: 'e.g. Gard AS, Swedish Club'),
            const SizedBox(height: 10),
            _field('Assured', _assuredCtrl, hint: 'e.g. Shipowner Pty Ltd'),
            const SizedBox(height: 16),

            // ── Organisation ─────────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            _sectionLabel('Organisation'),
            const SizedBox(height: 10),

            Consumer(builder: (context, ref, _) {
              final orgsAsync = ref.watch(organisationsProvider);
              return orgsAsync.when(
                loading: () => const SizedBox(
                    height: 56,
                    child: Center(child: LinearProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
                data: (orgs) => DropdownButtonFormField<String?>(
                  initialValue:
                      orgs.any((o) => o.organisationId == _organisationId)
                          ? _organisationId
                          : null,
                  decoration: _inputDeco('Firm / Organisation'),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— None —',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary))),
                    ...orgs.map((o) => DropdownMenuItem(
                          value: o.organisationId,
                          child: Text(o.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _organisationId = v),
                ),
              );
            }),
            const SizedBox(height: 16),

            // ── Financials ───────────────────────────────────────────────
            const Divider(height: 1),
            const SizedBox(height: 14),
            _sectionLabel('Financials'),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue:
                  _kCurrencies.contains(_baseCurrency) ? _baseCurrency : null,
              decoration: _inputDeco('Base Currency'),
              items: _kCurrencies
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child:
                            Text(c, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _baseCurrency = v),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      );

  Widget _datePicker({
    required String label,
    required IconData icon,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
    required VoidCallback onCleared,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value != null
                  ? '${value.day.toString().padLeft(2, '0')}/'
                      '${value.month.toString().padLeft(2, '0')}/'
                      '${value.year}'
                  : label,
              style: TextStyle(
                fontSize: 14,
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: onCleared,
              child: const Icon(Icons.clear,
                  size: 16, color: AppColors.textTertiary),
            ),
        ]),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _field(String label, TextEditingController ctrl, {String? hint}) =>
      TextField(
        controller: ctrl,
        style:
            const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: _inputDeco(label, hint: hint),
      );
}
