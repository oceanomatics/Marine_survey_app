// lib/features/documents/widgets/doc_type_selector_sheet.dart

import 'package:flutter/material.dart';
import '../providers/document_provider.dart';
import '../../../shared/theme/app_theme.dart';

class DocImportResult {
  const DocImportResult({required this.category, this.contextNotes});
  final DocCategory category;
  final String? contextNotes;
}

/// Opens a bottom sheet to select document type and optionally add context
/// notes for AI extraction. Returns null if dismissed.
Future<DocImportResult?> showDocTypeSelectorSheet(BuildContext context) {
  return showModalBottomSheet<DocImportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DocTypeSelectorSheet(),
  );
}

// Categories that trigger AI extraction and benefit from context notes.
const _aiCategories = {
  DocCategory.inspectionReport,
  DocCategory.classReport,
};

class _DocTypeSelectorSheet extends StatefulWidget {
  const _DocTypeSelectorSheet();

  @override
  State<_DocTypeSelectorSheet> createState() => _DocTypeSelectorSheetState();
}

class _DocTypeSelectorSheetState extends State<_DocTypeSelectorSheet> {
  DocCategory? _selected;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onTypeTapped(DocCategory category) {
    if (_aiCategories.contains(category)) {
      // Go to context-notes step.
      setState(() => _selected = category);
    } else {
      Navigator.pop(context, DocImportResult(category: category));
    }
  }

  void _confirm() {
    final notes = _notesCtrl.text.trim();
    Navigator.pop(
      context,
      DocImportResult(
        category: _selected!,
        contextNotes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: _selected == null ? _buildTypeStep() : _buildContextStep(),
      ),
    );
  }

  // ── Step 1: document type ──────────────────────────────────────────────────

  Widget _buildTypeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _DragHandle()),
        const SizedBox(height: 16),
        const Text('What are you importing?',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text(
          'Select the document type — this determines\nhow it is processed and stored.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        const _SectionHeader(
          icon: Icons.auto_awesome_outlined,
          label: 'AI extracts to case data',
          color: AppColors.purple,
        ),
        const SizedBox(height: 8),
        _TypeRow(
          icon: Icons.article_outlined,
          color: AppColors.purple,
          title: 'Previous Survey Report',
          subtitle: 'PDF or DOCX — Claude extracts vessel, damage & attendees',
          category: DocCategory.inspectionReport,
          onTap: _onTypeTapped,
        ),
        const SizedBox(height: 6),
        _TypeRow(
          icon: Icons.verified_user_outlined,
          color: AppColors.teal,
          title: 'Class / Flag Survey Report',
          subtitle: 'Classification or flag state survey in PDF or DOCX',
          category: DocCategory.classReport,
          onTap: _onTypeTapped,
        ),
        const SizedBox(height: 6),
        _TypeRow(
          icon: Icons.card_membership_outlined,
          color: AppColors.amber,
          title: 'Certificate',
          subtitle: 'Class cert, SMC, DOC, IOPP, Load Line — photo or PDF',
          category: DocCategory.certificate,
          onTap: _onTypeTapped,
        ),

        const SizedBox(height: 20),

        const _SectionHeader(
          icon: Icons.folder_outlined,
          label: 'Stored as reference document',
          color: AppColors.midBlue,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TypeChip(icon: Icons.build_circle_outlined,  color: AppColors.midBlue,       label: 'Service / Diver Report',  category: DocCategory.serviceReport,      onTap: _onTypeTapped),
            _TypeChip(icon: Icons.assignment_outlined,    color: AppColors.coral,          label: 'Statement of Facts',      category: DocCategory.statementOfFacts,   onTap: _onTypeTapped),
            _TypeChip(icon: Icons.menu_book_outlined,     color: AppColors.navy,           label: 'Logbook Extract',         category: DocCategory.logbookExtract,     onTap: _onTypeTapped),
            _TypeChip(icon: Icons.engineering_outlined,   color: AppColors.green,          label: 'Maintenance Record',      category: DocCategory.maintenanceRecord,  onTap: _onTypeTapped),
            _TypeChip(icon: Icons.science_outlined,       color: AppColors.teal,           label: 'Oil Analysis',            category: DocCategory.oilAnalysis,        onTap: _onTypeTapped),
            _TypeChip(icon: Icons.receipt_outlined,       color: AppColors.amber,          label: 'Invoice',                 category: DocCategory.invoice,            onTap: _onTypeTapped),
            _TypeChip(icon: Icons.mail_outlined,          color: AppColors.purple,         label: 'Correspondence',          category: DocCategory.correspondence,     onTap: _onTypeTapped),
            _TypeChip(icon: Icons.description_outlined,   color: AppColors.textSecondary,  label: 'Other',                   category: DocCategory.other,              onTap: _onTypeTapped),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Step 2: context notes ──────────────────────────────────────────────────

  Widget _buildContextStep() {
    final sel = _selected!;
    final color = sel == DocCategory.inspectionReport
        ? AppColors.purple
        : AppColors.teal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _DragHandle()),
        const SizedBox(height: 16),

        // Back + selected type badge
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 2),
              Text('Back',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              sel == DocCategory.inspectionReport
                  ? 'Previous Survey Report'
                  : 'Class / Flag Survey Report',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        const Text('Add context for Claude (optional)',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text(
          'Tell Claude what this document represents in your current survey. '
          'This improves extraction accuracy, especially for historical reports '
          'or documents covering multiple occurrences.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText:
                'e.g. "Previous grounding report 2022 — same vessel, for background context only. '
                'Do not import occurrences." or "Current survey report — import everything."',
            hintStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                height: 1.5),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Examples
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ExampleChip(
              label: 'Background context only',
              onTap: () => _notesCtrl.text =
                  'Previous report — use for background context only, do not import occurrences or damage items.',
            ),
            _ExampleChip(
              label: 'Import everything',
              onTap: () => _notesCtrl.text =
                  'Current survey report — import all sections.',
            ),
            _ExampleChip(
              label: 'Vessel particulars only',
              onTap: () => _notesCtrl.text =
                  'Historical report — import vessel particulars only, skip occurrences and damage.',
            ),
          ],
        ),

        const SizedBox(height: 20),

        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(
                  context, DocImportResult(category: sel)),
              child: const Text('Skip — no notes'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('Continue to import'),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.7,
          ),
        ),
      ]);
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DocCategory category;
  final ValueChanged<DocCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(category),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              _aiCategories.contains(category)
                  ? Icons.arrow_forward_ios
                  : Icons.chevron_right,
              color: color.withValues(alpha: 0.4),
              size: 16,
            ),
          ]),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.category,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final DocCategory category;
  final ValueChanged<DocCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTap(category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.lightBlue.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.midBlue.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.midBlue,
                fontWeight: FontWeight.w500),
          ),
        ),
      );
}
