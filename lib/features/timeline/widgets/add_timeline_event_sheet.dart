// lib/features/timeline/widgets/add_timeline_event_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/timeline_event_model.dart';
import '../../../shared/theme/app_theme.dart';

const _kColor = Color(0xFF2E7CB7);

class AddTimelineEventSheet extends StatefulWidget {
  const AddTimelineEventSheet({super.key, required this.onSave});

  final Future<void> Function(TimelineEventModel) onSave;

  @override
  State<AddTimelineEventSheet> createState() => _AddTimelineEventSheetState();
}

class _AddTimelineEventSheetState extends State<AddTimelineEventSheet> {
  TimelineEventType _type = TimelineEventType.vesselDeparture;
  DateTime? _date;

  final _titleCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl     = TextEditingController();

  bool _saving = false;
  String? _error;

  // Track if the user has manually edited the title so we don't overwrite it
  bool _titleEdited = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = _type.label;
    _titleCtrl.addListener(() => _titleEdited = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _setType(TimelineEventType t) {
    setState(() {
      _type = t;
      if (!_titleEdited || _titleCtrl.text.isEmpty) {
        _titleEdited = false;
        _titleCtrl.text = t.label;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('en', 'AU'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final model = TimelineEventModel(
        eventId:     '',
        caseId:      '',
        eventType:   _type,
        eventDate:   _date,
        title:       _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        location:    _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      await widget.onSave(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timeline, color: _kColor, size: 17),
                ),
                const SizedBox(width: 10),
                const Text('Add Timeline Event',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Event type ────────────────────────────────────────────────
            const _Label('Event type'),
            const SizedBox(height: 8),
            _TypeGroup(
              heading: 'Vessel Movement',
              types: const [
                TimelineEventType.vesselDeparture,
                TimelineEventType.vesselArrival,
                TimelineEventType.drydockEntry,
                TimelineEventType.drydockExit,
              ],
              selected: _type,
              onSelect: _setType,
            ),
            const SizedBox(height: 6),
            _TypeGroup(
              heading: 'Repairs',
              types: const [
                TimelineEventType.tempRepairStart,
                TimelineEventType.tempRepairComplete,
                TimelineEventType.permRepairStart,
                TimelineEventType.permRepairComplete,
              ],
              selected: _type,
              onSelect: _setType,
            ),
            const SizedBox(height: 6),
            _TypeGroup(
              heading: 'Other',
              types: const [
                TimelineEventType.surveyorRemark,
                TimelineEventType.custom,
              ],
              selected: _type,
              onSelect: _setType,
            ),
            const SizedBox(height: 16),

            // ── Date ──────────────────────────────────────────────────────
            const _Label('Date'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _date != null
                          ? DateFormat('dd/MM/yyyy').format(_date!)
                          : 'Select date',
                      style: TextStyle(
                          fontSize: 14,
                          color: _date != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary),
                    ),
                    if (_date != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _date = null),
                        child: const Icon(Icons.clear,
                            size: 16, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Title ─────────────────────────────────────────────────────
            _field('Title / Label', _titleCtrl,
                hint: 'e.g. Vessel departed Port of Brisbane'),
            const SizedBox(height: 12),

            // ── Location ──────────────────────────────────────────────────
            _field('Location', _locationCtrl,
                hint: 'e.g. Captain Cook Drydock, Sydney'),
            const SizedBox(height: 12),

            // ── Notes ─────────────────────────────────────────────────────
            _field('Notes', _descCtrl,
                hint: 'Any additional detail…', maxLines: 3),
            const SizedBox(height: 18),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.error)),
                    ),
                  ],
                ),
              ),

            // ── Save ──────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add to Timeline',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        labelStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

// ── Type group (labelled row of chips) ───────────────────────────────────

class _TypeGroup extends StatelessWidget {
  const _TypeGroup({
    required this.heading,
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  final String heading;
  final List<TimelineEventType> types;
  final TimelineEventType selected;
  final ValueChanged<TimelineEventType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.4)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: types.map((t) {
            final sel = selected == t;
            const accent = Color(0xFF2E7CB7);
            return GestureDetector(
              onTap: () => onSelect(t),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? accent.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? accent : AppColors.border,
                      width: sel ? 1.5 : 1),
                ),
                child: Text(
                  t.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel ? accent : AppColors.textSecondary),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));
}
