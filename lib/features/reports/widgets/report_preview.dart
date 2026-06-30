// lib/features/reports/widgets/report_preview.dart
//
// Renders the assembled report sections as a formatted document
// preview — matches the visual style of the actual Word output.

import 'package:flutter/material.dart';
import '../providers/report_provider.dart';
import '../../../shared/theme/app_theme.dart';

class ReportPreview extends StatelessWidget {
  const ReportPreview({
    super.key,
    required this.output,
    required this.assembled,
    required this.sections,
  });

  final ReportOutput output;
  final AssembledReportData assembled;
  final Map<SectionType, ReportSection> sections;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Page 1 — document shell ──────────────────────────────
          _PreviewPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ABL / company header
                _CompanyHeader(assembled: assembled),
                const SizedBox(height: 24),

                // Report title block
                _TitleBlock(output: output, assembled: assembled),
                const SizedBox(height: 20),

                // Opening clause (locked)
                if (sections[SectionType.opening] != null)
                  _PreviewSection(
                    section: sections[SectionType.opening]!,
                    showTitle: false,
                  ),
                const SizedBox(height: 16),

                // Attending the survey table
                if (sections[SectionType.attendees] != null) ...[
                  const _PreviewHeading('ATTENDING THE SURVEY'),
                  _AttendeesTable(assembled: assembled),
                  const SizedBox(height: 16),
                ],

                // Vessel particulars
                if (sections[SectionType.vesselParticulars] != null) ...[
                  const _PreviewHeading("VESSEL'S DESCRIPTION"),
                  _VesselBlock(assembled: assembled),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Page 2 — occurrence and damage ──────────────────────
          _PreviewPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Occurrence
                if (sections[SectionType.occurrence] != null) ...[
                  const _PreviewHeading('OCCURRENCE'),
                  _PreviewSection(
                      section: sections[SectionType.occurrence]!,
                      showTitle: false),
                  const SizedBox(height: 16),
                ],

                // Background
                if (sections[SectionType.background] != null) ...[
                  const _PreviewHeading('BACKGROUND'),
                  _PreviewSection(
                      section: sections[SectionType.background]!,
                      showTitle: false),
                  const SizedBox(height: 16),
                ],

                // Damage description
                if (sections[SectionType.damageDescription] != null) ...[
                  const _PreviewHeading('EXTENT OF DAMAGE'),
                  _PreviewSection(
                      section: sections[SectionType.damageDescription]!,
                      showTitle: false),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Page 3 — cause, allegation, closing ─────────────────
          _PreviewPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sections[SectionType.repairs] != null) ...[
                  const _PreviewHeading('REPAIRS'),
                  _PreviewSection(
                      section: sections[SectionType.repairs]!,
                      showTitle: false),
                  const SizedBox(height: 16),
                ],
                if (sections[SectionType.causation] != null) ...[
                  const _PreviewHeading('CAUSE CONSIDERATION'),
                  _PreviewSection(
                      section: sections[SectionType.causation]!,
                      showTitle: false),
                  const SizedBox(height: 16),
                ],
                if (sections[SectionType.allegation] != null) ...[
                  const _PreviewHeading('ALLEGATION / CAUSATION'),
                  _PreviewSection(
                      section: sections[SectionType.allegation]!,
                      showTitle: false,
                      isLocked: true),
                  const SizedBox(height: 16),
                ],
                if (sections[SectionType.closing] != null) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  _PreviewSection(
                      section: sections[SectionType.closing]!,
                      showTitle: false,
                      isLocked: true,
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                          height: 1.4,
                          fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Page shell ─────────────────────────────────────────────────────────────

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: child,
    );
  }
}

// ── Company header ─────────────────────────────────────────────────────────

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.assembled});
  final AssembledReportData assembled;

  @override
  Widget build(BuildContext context) {
    final format = assembled.outputFormat;
    final companyName = format == 'nordic'
        ? 'ABL Energy & Marine Consultants Ltd'
        : 'ABL London Limited';
    final address = format == 'nordic'
        ? '112 Robinson Road, #09-01\nSingapore, 068902'
        : '1st Floor, The Northern & Shell Building\n10 Lower Thames Street\nLondon, EC3R 6EN, U.K.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(companyName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              Text(address,
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                      height: 1.5)),
            ],
          ),
        ),
        // Case reference block
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaRow('Technical File No.',
                  assembled.caseData['technical_file_no'] as String? ?? ''),
              _MetaRow('Report No.',
                  assembled.caseData['technical_file_no'] as String? ?? ''),
              _MetaRow('Report Date',
                  _today()),
            ],
          ),
        ),
      ],
    );
  }

  String _today() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}-'
        '${_month(d.month)}-${d.year}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(
          width: 70,
          child: Text('$label :',
              style: const TextStyle(
                  fontSize: 8, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]),
    );
  }
}

// ── Title block ────────────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  const _TitleBlock(
      {required this.output, required this.assembled});
  final ReportOutput output;
  final AssembledReportData assembled;

  @override
  Widget build(BuildContext context) {
    final vesselName =
        assembled.vessel?['name'] as String? ?? '"VESSEL NAME"';
    final reportType = output.outputType.label.toUpperCase();

    return Column(
      children: [
        Text(
          reportType,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          'M.V. "$vesselName"',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        if (assembled.occurrences.isNotEmpty)
          Text(
            assembled.occurrences.first['title'] as String? ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

// ── Attendees table ────────────────────────────────────────────────────────

class _AttendeesTable extends StatelessWidget {
  const _AttendeesTable({required this.assembled});
  final AssembledReportData assembled;

  @override
  Widget build(BuildContext context) {
    if (assembled.attendees.isEmpty) {
      return const Text('[No attendees recorded]',
          style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary));
    }

    return Table(
      border: TableBorder.all(
          color: AppColors.border, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
      },
      children: [
        const TableRow(
          decoration:
              BoxDecoration(color: AppColors.lightBlue),
          children: [
            _TH('Name & Position'),
            _TH('Representing'),
          ],
        ),
        ...assembled.attendees.map((a) => TableRow(children: [
              _TD('${a['rank_position'] ?? ''} ${a['full_name'] ?? ''}'),
              _TD(a['representing'] ?? a['company'] ?? ''),
            ])),
      ],
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(5),
        child: Text(text,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
      );
}

class _TD extends StatelessWidget {
  const _TD(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(5),
        child: Text(text,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textPrimary)),
      );
}

// ── Vessel block ───────────────────────────────────────────────────────────

class _VesselBlock extends StatelessWidget {
  const _VesselBlock({required this.assembled});
  final AssembledReportData assembled;

  @override
  Widget build(BuildContext context) {
    final v = assembled.vessel;
    if (v == null) {
      return const Text('[Vessel particulars not recorded]',
          style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary));
    }

    final rows = <(String, String)>[
      ('Type', v['vessel_type'] as String? ?? ''),
      ('IMO Number', v['imo_number'] as String? ?? ''),
      ('GT / DWT',
          '${v['gross_tonnage'] ?? ''} / ${v['deadweight'] ?? ''}'),
      ('Flag / Home Port',
          '${v['flag'] ?? ''} / ${v['port_of_registry'] ?? ''}'),
      ('Built', '${v['build_yard'] ?? ''}, ${v['build_country'] ?? ''} / ${v['year_built'] ?? ''}'),
      ('Owners', v['owners'] as String? ?? ''),
      ('Class', '${v['class_society'] ?? ''} — ${v['class_notation'] ?? ''}'),
    ];

    return Column(
      children: rows
          .where((r) => r.$2.isNotEmpty && r.$2 != ' / ' && r.$2 != ' — ')
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text('${r.$1}:',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Preview section ────────────────────────────────────────────────────────

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.section,
    required this.showTitle,
    this.isLocked = false,
    this.style,
  });

  final ReportSection section;
  final bool showTitle;
  final bool isLocked;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          _PreviewHeading(section.title.toUpperCase()),
          const SizedBox(height: 6),
        ],
        if (isLocked)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.lightPurple.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.2)),
            ),
            child: Text(
              section.content,
              style: style ??
                  const TextStyle(
                      fontSize: 9,
                      color: AppColors.textPrimary,
                      height: 1.5),
            ),
          )
        else
          Text(
            section.content.isEmpty
                ? '[${section.title} — not yet completed]'
                : section.content,
            style: style ??
                TextStyle(
                  fontSize: 9.5,
                  color: section.content.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  height: 1.6,
                  fontStyle: section.content.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
          ),
      ],
    );
  }
}

class _PreviewHeading extends StatelessWidget {
  const _PreviewHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
