import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/accounts_models.dart';
import '../../../features/survey/models/repair_period_model.dart';
import '../../../features/survey/providers/damage_provider.dart';
import '../../../shared/theme/app_theme.dart';

const _kAccent = Color(0xFF2E7D32);
const _uuid = Uuid();
const _kPreliminary = 'preliminary_expense';

class EditAccountLineSheet extends StatefulWidget {
  const EditAccountLineSheet({
    super.key,
    required this.caseId,
    required this.documentId,
    this.existing,
    required this.defaultCurrency,
    required this.onSave,
    this.occurrences = const [],
    this.repairPeriods = const [],
  });
  final String caseId;
  final String documentId;
  final AccountLineModel? existing;
  final String defaultCurrency;
  final Future<void> Function(AccountLineModel line) onSave;
  final List<OccurrenceModel> occurrences;
  final List<RepairPeriodModel> repairPeriods;

  @override
  State<EditAccountLineSheet> createState() => _EditAccountLineSheetState();
}

class _EditAccountLineSheetState extends State<EditAccountLineSheet> {
  late TextEditingController _descCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _apportionValueCtrl;
  late TextEditingController _notesCtrl;

  late CostNature _costNature;
  late LineItemStatus _status;
  String? _apportionmentType;
  String? _repairPeriodId;
  String? _occurrenceId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _descCtrl = TextEditingController(text: e?.description ?? '');
    // Prefer grossAmount; fall back to underwritersPortion for legacy lines
    _amountCtrl = TextEditingController(
        text: e != null && e.grossAmount > 0
            ? e.grossAmount.toStringAsFixed(2)
            : (e != null && e.underwritersPortion > 0
                ? e.underwritersPortion.toStringAsFixed(2)
                : ''));
    _amountCtrl.addListener(() => setState(() {}));
    _apportionValueCtrl = TextEditingController(
        text: e?.apportionmentValue != null
            ? e!.apportionmentValue!.toStringAsFixed(2)
            : '');
    _apportionValueCtrl.addListener(() => setState(() {}));
    _notesCtrl = TextEditingController(text: e?.apportionmentNotes ?? '');
    _costNature = e?.costNature ?? CostNature.serviceTechnician;
    _status = e?.status ?? LineItemStatus.pendingReview;
    _apportionmentType = e?.apportionmentType;
    _repairPeriodId = e?.repairPeriodId;
    _occurrenceId = e?.occurrenceId ??
        (widget.occurrences.length == 1
            ? widget.occurrences.first.occurrenceId
            : null);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _apportionValueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _claimLabel {
    if (_occurrenceId == null) return 'Approved';
    final idx = widget.occurrences
        .indexWhere((o) => o.occurrenceId == _occurrenceId);
    final occ = idx >= 0 ? widget.occurrences[idx] : null;
    final name = occ?.title ?? 'Claim';
    return idx >= 0
        ? 'Approved — Occ. ${idx + 1} — $name'
        : 'Approved — $name';
  }

  ({double claim, double owners, double deferred}) get _computedSplit {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final apportionValue =
        double.tryParse(_apportionValueCtrl.text.replaceAll(',', ''));

    if (_status == LineItemStatus.approved ||
        _status == LineItemStatus.betterment) {
      return (claim: amount, owners: 0, deferred: 0);
    }
    if (_status == LineItemStatus.rejected) {
      return (claim: 0, owners: amount, deferred: 0);
    }
    if (_status == LineItemStatus.apportioned) {
      if (_apportionmentType == 'percentage' && apportionValue != null) {
        final claim = amount * apportionValue / 100;
        return (claim: claim, owners: amount - claim, deferred: 0);
      }
      if (_apportionmentType == 'amount' && apportionValue != null) {
        final owners = apportionValue.clamp(0, amount).toDouble();
        return (claim: amount - owners, owners: owners, deferred: 0);
      }
      if (_apportionmentType == 'defer') {
        return (claim: 0, owners: 0, deferred: amount);
      }
    }
    return (claim: 0, owners: 0, deferred: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final split = _computedSplit;
    final hasSplit =
        split.claim > 0.005 || split.owners > 0.005 || split.deferred > 0.005;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit Invoice Line Item' : 'Add Invoice Line Item',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── Description ──────────────────────────────────────────
                  _field('Description (verbatim from invoice)', _descCtrl,
                      maxLines: 3),
                  const SizedBox(height: 8),
                  _field('Line amount (${widget.defaultCurrency})', _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 12),

                  // ── Cost nature ──────────────────────────────────────────
                  _section('Cost Nature'),
                  _dropdownRow<CostNature>(
                    label: 'Type of service / work',
                    value: _costNature,
                    items: CostNature.values,
                    labelOf: (v) => v.label,
                    onChanged: (v) => setState(() => _costNature = v!),
                  ),
                  const SizedBox(height: 12),

                  // ── Status ───────────────────────────────────────────────
                  _section('Status'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: LineItemStatus.values
                        .map((s) => _StatusPill(
                              label: s.label,
                              color: _statusColor(s),
                              selected: _status == s,
                              onTap: () => setState(() {
                                _status = s;
                                if (s != LineItemStatus.apportioned) {
                                  _apportionmentType = null;
                                }
                              }),
                            ))
                        .toList(),
                  ),
                  if (_status == LineItemStatus.apportioned) ...[
                    const SizedBox(height: 10),
                    _ApportionSubOptions(
                      selected: _apportionmentType,
                      valueCtrl: _apportionValueCtrl,
                      onTypeChanged: (t) =>
                          setState(() => _apportionmentType = t),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // ── Allocation ───────────────────────────────────────────
                  _section('Allocation'),
                  if (widget.occurrences.isNotEmpty)
                    _dropdownNullable<String>(
                      label: 'Occurrence / Claim',
                      value: _occurrenceId,
                      items: widget.occurrences
                          .asMap()
                          .entries
                          .map((e) => DropdownMenuItem(
                                value: e.value.occurrenceId,
                                child: Text(
                                  'Occ. No. ${e.key + 1}  —  '
                                  '${e.value.title ?? 'Occurrence ${e.key + 1}'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _occurrenceId = v),
                    ),
                  if (widget.repairPeriods.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _dropdownNullable<String>(
                      label: 'Repair Period',
                      value: _repairPeriodId,
                      items: [
                        const DropdownMenuItem(
                          value: _kPreliminary,
                          child: Text('Preliminary Expense'),
                        ),
                        ...widget.repairPeriods.asMap().entries.map(
                              (e) => DropdownMenuItem(
                                value: e.value.periodId,
                                child: Text(
                                  'Period No. ${e.key + 1}  —  ${e.value.displayTitle}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
                      onChanged: (v) => setState(() => _repairPeriodId = v),
                    ),
                  ],
                  const SizedBox(height: 12),

                  if (hasSplit) ...[
                    _SplitDisplay(
                      split: split,
                      claimLabel: _claimLabel,
                      currency: widget.defaultCurrency,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Notes ────────────────────────────────────────────────
                  _section('Notes'),
                  _field('Apportionment / surveyor notes', _notesCtrl,
                      maxLines: 3),
                  const SizedBox(height: 20),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save Changes' : 'Add Line'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );

  Widget _field(String label, TextEditingController ctrl,
          {int maxLines = 1, TextInputType? keyboardType}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ],
      );

  Widget _dropdownRow<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6)),
              ),
            ),
            items: items
                .map((v) => DropdownMenuItem<T>(
                      value: v,
                      child:
                          Text(labelOf(v), overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      );

  Widget _dropdownNullable<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            hint: const Text('— not allocated —',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6)),
              ),
            ),
            items: items,
            onChanged: onChanged,
          ),
        ],
      );

  Color _statusColor(LineItemStatus s) => switch (s) {
        LineItemStatus.approved    => _kAccent,
        LineItemStatus.queried     => Colors.orange,
        LineItemStatus.apportioned => Colors.teal,
        LineItemStatus.betterment  => Colors.brown,
        LineItemStatus.rejected    => Colors.red,
        _                          => AppColors.textSecondary,
      };

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Description is required.');
      return;
    }
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final apportionValue =
        _apportionmentType != null && _apportionmentType != 'defer'
            ? double.tryParse(_apportionValueCtrl.text.replaceAll(',', ''))
            : null;
    final split = _computedSplit;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final line = AccountLineModel(
        id: widget.existing?.id ?? _uuid.v4(),
        documentId: widget.documentId,
        caseId: widget.caseId,
        lineOrder: widget.existing?.lineOrder ?? 0,
        itemNumber: widget.existing?.itemNumber,
        description: desc,
        costNature: _costNature,
        grossAmount: amount,
        underwritersPortion: split.claim,
        ownersPortion: split.owners,
        apportionmentNotes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        apportionmentType: _status == LineItemStatus.apportioned
            ? _apportionmentType
            : null,
        apportionmentValue: _status == LineItemStatus.apportioned
            ? apportionValue
            : null,
        status: _status,
        aiDraft: widget.existing?.aiDraft,
        repairPeriodId: _repairPeriodId,
        occurrenceId: _occurrenceId,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await widget.onSave(line);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Save failed: $e';
        });
      }
    }
  }
}

// ── Split display ──────────────────────────────────────────────────────────

class _SplitDisplay extends StatelessWidget {
  const _SplitDisplay({
    required this.split,
    required this.claimLabel,
    required this.currency,
  });
  final ({double claim, double owners, double deferred}) split;
  final String claimLabel;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (split.claim > 0.005) {
      rows.add(_AmountRow(
        label: claimLabel,
        amount: split.claim,
        currency: currency,
        color: const Color(0xFF2E7D32),
      ));
    }
    if (split.owners > 0.005) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(_AmountRow(
        label: "Owner's account",
        amount: split.owners,
        currency: currency,
        color: Colors.orange,
      ));
    }
    if (split.deferred > 0.005) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 6));
      rows.add(_AmountRow(
        label: 'Deferred to adjuster',
        amount: split.deferred,
        currency: currency,
        color: Colors.blueGrey,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Column(children: rows),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });
  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Label gets ~60% of available width and may wrap
        Flexible(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        // Dots + amount share the remaining ~40%
        Flexible(
          flex: 2,
          child: Row(
            children: [
              const Expanded(
                child: SizedBox(
                  height: 14,
                  child: CustomPaint(
                    painter: _DotLeaderPainter(AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$currency ${_fmt(amount)}',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final integral = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '$integral.${parts[1]}';
  }
}

class _DotLeaderPainter extends CustomPainter {
  const _DotLeaderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dotW = 1.5;
    const gap = 5.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dotW, y), paint);
      x += dotW + gap;
    }
  }

  @override
  bool shouldRepaint(_DotLeaderPainter old) => old.color != color;
}

// ── Apportionment sub-options ─────────────────────────────────────────────

class _ApportionSubOptions extends StatelessWidget {
  const _ApportionSubOptions({
    required this.selected,
    required this.valueCtrl,
    required this.onTypeChanged,
  });
  final String? selected;
  final TextEditingController valueCtrl;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Apportionment basis',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SubPill('% to claim', 'percentage', selected, onTypeChanged),
              _SubPill('Deduct to owners', 'amount', selected, onTypeChanged),
              _SubPill('Defer to adjuster', 'defer', selected, onTypeChanged),
            ],
          ),
          if (selected == 'percentage' || selected == 'amount') ...[
            const SizedBox(height: 8),
            TextField(
              controller: valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: selected == 'percentage'
                    ? 'e.g. 70  →  70% goes to claim'
                    : 'Amount to owner\'s account',
                hintStyle:
                    const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.6)),
                ),
                suffixText: selected == 'percentage' ? '% to claim' : null,
              ),
            ),
          ],
          if (selected == 'defer') ...[
            const SizedBox(height: 6),
            const Text(
              'Full line amount deferred — adjuster to determine allocation.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubPill extends StatelessWidget {
  const _SubPill(this.label, this.value, this.selected, this.onChanged);
  final String label;
  final String value;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? Colors.teal : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
}
