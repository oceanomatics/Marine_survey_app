// lib/features/reports/widgets/new_output_sheet.dart

import 'package:flutter/material.dart';
import '../providers/report_provider.dart';
import '../../../shared/theme/app_theme.dart';

class NewOutputSheet extends StatefulWidget {
  const NewOutputSheet({
    super.key,
    required this.caseId,
    required this.jobNumber,
    required this.existingCount,
    required this.onCreate,
  });

  final String caseId;
  final String jobNumber;
  final int existingCount;
  final Future<void> Function(
      OutputType type, String reportNumber, int sequenceNo) onCreate;

  @override
  State<NewOutputSheet> createState() => _NewOutputSheetState();
}

class _NewOutputSheetState extends State<NewOutputSheet> {
  OutputType _type = OutputType.preliminary;
  final _numberCtrl = TextEditingController();
  int _sequenceNo = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final next = (widget.existingCount + 1).toString().padLeft(3, '0');
    _numberCtrl.text = '${widget.jobNumber}-R$next';
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_numberCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onCreate(
          _type, _numberCtrl.text.trim(), _sequenceNo);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('New Report Output',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          // Type selector — visual buttons
          Row(children: OutputType.values.map((t) {
            final selected = _type == t;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _type = t;
                    if (t == OutputType.advice) _sequenceNo = 1;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.navy
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? AppColors.navy
                            : AppColors.border,
                      ),
                    ),
                    child: Column(children: [
                      Icon(
                        t == OutputType.preliminary
                            ? Icons.flash_on_outlined
                            : t == OutputType.advice
                                ? Icons.update_outlined
                                : Icons.done_all_outlined,
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }).toList()),

          if (_type == OutputType.advice) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Text('Advice Number:',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              ...List.generate(5, (i) => i + 1).map((n) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _sequenceNo = n),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _sequenceNo == n
                              ? AppColors.navy
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _sequenceNo == n
                                ? AppColors.navy
                                : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text('$n',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _sequenceNo == n
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                        ),
                      ),
                    ),
                  )),
            ]),
          ],

          const SizedBox(height: 14),

          // Report number
          const Text('Report Number',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 5),
          TextField(
            controller: _numberCtrl,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. SI-M53-055873-R001',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _create,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Create ${_type.label}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
