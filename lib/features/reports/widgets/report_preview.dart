// lib/features/reports/widgets/report_preview.dart
//
// WYSIWYG A4 report preview — mirrors the docx output visually.
// Page 1: Cover · Page 2: Executive Summary · Page 3: TOC · Pages 4+: flowing body

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../utils/section_text.dart';
import '../../photos/models/photo_model.dart';
import '../../photos/providers/photo_provider.dart';

// Cap on the on-screen preview page's rendered width, so the "page" stays a
// realistic, WYSIWYG size and is centred with grey canvas either side on
// wide/desktop windows, instead of stretching edge-to-edge (which breaks the
// A4 look even though the height:width ratio itself was always correct).
// Narrower viewports (phone/tablet) are unaffected — the page still shrinks
// to fit, this only clamps the upper bound.
const double _kA4PreviewMaxWidth = 850;

// ── Height estimation helpers ──────────────────────────────────────────────
//
// These are rough approximations used only for section-to-page grouping.
// The actual docx layout engine decides real page breaks.

double _estimateSectionPx(ReportSection s, double contentW) {
  const headingH = 29.0; // title + 1.5px rule + SizedBox(10)
  const lineH = 14.7; // 9.5 * 1.55
  const avgCharW = 5.5;
  const minLines = 1;

  if (s.content.isEmpty) return headingH + 16.0;

  final cpl = (contentW / avgCharW).round().clamp(20, 80);
  var lines = 0;
  for (final raw in s.content.split('\n')) {
    final l = raw.isEmpty ? 0 : raw.length;
    lines += (l == 0 ? 1 : (l / cpl).ceil()).clamp(minLines, 200);
  }
  return headingH + lines * lineH + 8.0;
}

// Groups sections into A4 pages. Returns one list per page.
List<List<ReportSection>> _paginateSections(
    List<ReportSection> sections, double pageH, double contentW) {
  // Fixed overhead per body page (header + footer + vertical padding)
  const overheadH = 30.0 + 23.0 + 36.0; // header + footer + content pad
  final availH = (pageH - overheadH).clamp(100.0, double.infinity);

  // Minimum height needed so a section is not orphaned
  // (heading + at least 2 lines of content must fit)
  const orphanH = 29.0 + 14.7 * 2;

  final pages = <List<ReportSection>>[];
  var page = <ReportSection>[];
  var used = 0.0;

  for (final s in sections) {
    final h = _estimateSectionPx(s, contentW);

    if (page.isEmpty) {
      page.add(s);
      used = h;
    } else if (used + h <= availH) {
      // Fits cleanly on the current page
      page.add(s);
      used += h;
    } else if (availH - used < orphanH) {
      // Less than orphan threshold remains → push section to next page
      pages.add(List.of(page));
      page = [s];
      used = h;
    } else {
      // Heading + a few lines will show; rest overflows — acceptable for preview
      page.add(s);
      used += h;
    }
  }

  if (page.isNotEmpty) pages.add(page);
  return pages;
}

// ── TOC data ───────────────────────────────────────────────────────────────

class _TocEntry {
  const _TocEntry(this.title, this.page);
  final String title; // already includes number prefix e.g. "1.  Opening"
  final int page;
}

// ── Public widget ──────────────────────────────────────────────────────────

class ReportPreview extends ConsumerWidget {
  const ReportPreview({
    super.key,
    required this.output,
    required this.assembled,
    required this.sections,
    required this.caseId,
  });

  final ReportOutput output;
  final AssembledReportData assembled;
  final Map<SectionType, ReportSection> sections;
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final org = assembled.organisation;
    final brand = _Brand.fromOrg(org);
    final v = assembled.vessel ?? {};
    final c = assembled.caseData;

    final photos = ref.watch(photosProvider(caseId)).value ?? [];
    final coverPhoto = photos.coverPhoto;

    final vesselName = v['name'] as String? ?? '';
    final jobNo = c['technical_file_no'] as String? ?? '';
    final reportTypeLabel = switch (output.outputType) {
      OutputType.advice => 'Advice No ${output.sequenceNo}',
      OutputType.preliminary => 'Preliminary Report',
      OutputType.final_ => 'Final Report',
    };
    final hLeft = brand.firmName.isNotEmpty ? brand.firmName : 'Survey Report';
    final hRight = [
      if (jobNo.isNotEmpty) jobNo,
      if (vesselName.isNotEmpty) vesselName,
      reportTypeLabel,
    ].join(' — ');

    // Summary lives on page 2; body = everything else in §4.1 order
    final summarySection = sections[SectionType.executiveSummary];
    final bodyTypes = oceanoSectionOrder
        .where(
            (t) => t != SectionType.executiveSummary && sections.containsKey(t))
        .toList();
    final bodySections = bodyTypes.map((t) => sections[t]!).toList();

    // Page numbers for fixed pages
    final summaryPageNum = summarySection != null ? 2 : null;
    final tocPageNum = summarySection != null ? 3 : 2;
    final bodyStartPage = tocPageNum + 1;

    // Pagination — needs to know A4 dimensions at the actual rendered page
    // width, which is capped (see _kA4PreviewMaxWidth) so the page doesn't
    // balloon to the full window width on wide/desktop screens. Using the
    // raw screen width here would desync pagination from what's rendered.
    final screenW = MediaQuery.of(context).size.width;
    final containerW =
        screenW > _kA4PreviewMaxWidth ? _kA4PreviewMaxWidth : screenW;
    final pageW =
        containerW - 32; // ListView has 16px horizontal padding each side
    final pageH = pageW * 297 / 210;
    final contentW = pageW - 56; // 28px margins each side within the page

    final bodyPages = _paginateSections(bodySections, pageH, contentW);
    final totalPages = bodyStartPage - 1 + bodyPages.length;

    // Map each body section to its actual page number (for TOC accuracy)
    final sectionPages = <int>[];
    for (var gi = 0; gi < bodyPages.length; gi++) {
      for (var si = 0; si < bodyPages[gi].length; si++) {
        sectionPages.add(bodyStartPage + gi);
      }
    }

    // Section numbers parallel to bodyTypes / bodySections
    final sectionNumbers = bodyTypes.map(oceanoSectionNumber).toList();

    final tocEntries = List.generate(
      bodySections.length,
      (i) {
        final n = sectionNumbers[i];
        final title =
            n != null ? '$n.  ${bodySections[i].title}' : bodySections[i].title;
        return _TocEntry(title, sectionPages[i]);
      },
    );

    return ColoredBox(
      color: const Color(0xFFD0D0D0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kA4PreviewMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            children: [
              // Page 1: Cover (no running header/footer — uses its own firm strip)
              _A4Page(
                fixed: true,
                child: _CoverContent(
                  output: output,
                  assembled: assembled,
                  brand: brand,
                  coverPhoto: coverPhoto,
                ),
              ),

              const SizedBox(height: 20),

              // Page 2: Executive Summary
              if (summarySection != null) ...[
                _A4Page(
                  fixed: true,
                  child: _SummaryContent(
                    section: summarySection,
                    brand: brand,
                    headerLeft: hLeft,
                    headerRight: hRight,
                    pageNum: summaryPageNum!,
                    totalPages: totalPages,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Page 3 (or 2): Table of Contents
              _A4Page(
                fixed: true,
                child: _TocContent(
                  entries: tocEntries,
                  brand: brand,
                  headerLeft: hLeft,
                  headerRight: hRight,
                  pageNum: tocPageNum,
                  totalPages: totalPages,
                ),
              ),

              // Pages 4+: Flowing body sections — multiple sections per A4 page
              ...bodyPages.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _A4Page(
                      fixed: false,
                      child: _MultiSectionBodyContent(
                        sections: e.value,
                        sectionNumbers: e.value.map((s) {
                          final idx = bodySections.indexOf(s);
                          return idx >= 0 ? sectionNumbers[idx] : null;
                        }).toList(),
                        brand: brand,
                        headerLeft: hLeft,
                        headerRight: hRight,
                        pageNum: bodyStartPage + e.key,
                        totalPages: totalPages,
                      ),
                    ),
                  )),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand colour helper ────────────────────────────────────────────────────

class _Brand {
  const _Brand({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.firmName,
    this.firmCity = '',
    this.firmEmail = '',
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final String firmName;
  final String firmCity;
  final String firmEmail;

  static _Brand fromOrg(Map<String, dynamic>? org) => _Brand(
        primary: _hex(org?['primary_colour'] as String?, 0xFF1F3A5F),
        secondary: _hex(org?['secondary_colour'] as String?, 0xFF2C5282),
        accent: _hex(org?['accent_colour'] as String?, 0xFFEBF4FF),
        firmName: org?['name'] as String? ?? '',
        firmCity: org?['firm_city'] as String? ?? '',
        firmEmail: org?['firm_email'] as String? ?? '',
      );

  static Color _hex(String? raw, int fallback) {
    if (raw == null) return Color(fallback);
    final h = raw.replaceAll('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Color(fallback);
    }
  }

  Color get bodyText => const Color(0xFF374151);
  Color get subtleText => const Color(0xFF6B7280);
}

// ── A4 page shell ──────────────────────────────────────────────────────────
//
// fixed=true  → exact A4 height, content clips at boundary  (cover / summary / TOC)
// fixed=false → minimum A4 height, expands to content       (flowing body pages)

class _A4Page extends StatelessWidget {
  const _A4Page({required this.child, this.fixed = false});
  final Widget child;
  final bool fixed;

  static const double _kRatio = 297 / 210;

  static const BoxDecoration _kDecoration = BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = w * _kRatio;
      if (fixed) {
        return DecoratedBox(
          decoration: _kDecoration,
          child: SizedBox(width: w, height: h, child: ClipRect(child: child)),
        );
      }
      return DecoratedBox(
        decoration: _kDecoration,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: w, minHeight: h),
          child: child,
        ),
      );
    });
  }
}

// ── Cover page content (page 1) ───────────────────────────────────────────

class _CoverContent extends StatelessWidget {
  const _CoverContent({
    required this.output,
    required this.assembled,
    required this.brand,
    required this.coverPhoto,
  });

  final ReportOutput output;
  final AssembledReportData assembled;
  final PhotoModel? coverPhoto;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    final v = assembled.vessel ?? {};
    final c = assembled.caseData;
    final vesselName = v['name'] as String? ?? 'VESSEL NAME';
    final occ =
        assembled.occurrences.isNotEmpty ? assembled.occurrences.first : null;
    final occTitle = occ?['title'] as String? ?? '';
    final occDate = _fmtDate(occ?['date_time'] as String?);
    final claimRef = c['claim_reference'] as String? ?? '—';
    final fileNo = c['technical_file_no'] as String? ?? '—';
    final reportNo = output.reportNumber ?? output.versionCode;

    // Band colour: grey for preliminary (not the eye-hurting amber).
    // Pill colour: differs for preliminary so it stands out from the grey band.
    final bandColor = switch (output.outputType) {
      OutputType.final_ => const Color(0xFF059669), // emerald
      OutputType.advice => const Color(0xFF0284C7), // sky blue
      OutputType.preliminary => const Color(0xFF9CA3AF), // neutral grey
    };
    final pillColor = switch (output.outputType) {
      OutputType.final_ => const Color(0xFF059669),
      OutputType.advice => const Color(0xFF0284C7),
      OutputType.preliminary =>
        const Color(0xFF6D28D9), // violet — distinct from grey band
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Firm header bar ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.firmName.isNotEmpty
                          ? brand.firmName
                          : 'Survey Firm',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: brand.primary,
                      ),
                    ),
                    if (brand.firmCity.isNotEmpty)
                      Text(brand.firmCity,
                          style:
                              TextStyle(fontSize: 8, color: brand.subtleText)),
                  ],
                ),
              ),
              Text(
                DateTime.now().year.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: brand.subtleText,
                ),
              ),
            ],
          ),
        ),

        // ── Vessel name band (primary_colour) ─────────────────
        Container(
          color: brand.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'M.V.  "$vesselName"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // ── Report type band ───────────────────────────────────
        Container(
          color: bandColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${output.outputType.label.toUpperCase()}  ·  ${output.versionCode}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),

        // ── Occurrence description ─────────────────────────────
        if (occTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              occTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: brand.subtleText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        // ── Cover photo — absorbs remaining vertical space ──────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: BoxDecoration(
              color: coverPhoto != null && coverPhoto!.localPath.isNotEmpty
                  ? Colors.white
                  : const Color(0xFFE5E7EB),
            ),
            clipBehavior: Clip.antiAlias,
            child: coverPhoto != null && coverPhoto!.localPath.isNotEmpty
                ? Image.file(
                    File(coverPhoto!.localPath),
                    // Scale to fit, don't crop — cropping is a deliberate
                    // step done in the photo editor, not something the
                    // report preview/export should do automatically.
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.directions_boat_outlined,
                          size: 48, color: Color(0xFF9CA3AF)),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.directions_boat_outlined,
                        size: 48, color: Color(0xFF9CA3AF)),
                  ),
          ),
        ),

        // ── Info box (two columns, accent background) ──────────
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          decoration: BoxDecoration(
            color: brand.accent,
            border: Border.all(color: brand.primary.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CoverInfoBlock(
                  label: 'Occurrence',
                  value: [
                    if (occDate.isNotEmpty) occDate,
                    if (occTitle.isNotEmpty) occTitle,
                  ].join('\n'),
                  brand: brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CoverInfoBlock(
                        label: "Claim's Reference",
                        value: claimRef,
                        brand: brand),
                    const SizedBox(height: 4),
                    _CoverInfoBlock(
                        label: 'Technical File No.',
                        value: fileNo,
                        brand: brand),
                    const SizedBox(height: 4),
                    _CoverInfoBlock(
                        label: 'Report No.', value: reportNo, brand: brand),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Status pill + date ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '● ${output.outputType.label.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Report Date: ${_today()}',
                      style: TextStyle(fontSize: 8, color: brand.bodyText)),
                  if (brand.firmName.isNotEmpty)
                    Text('Prepared by: ${brand.firmName}',
                        style: TextStyle(fontSize: 8, color: brand.subtleText)),
                ],
              ),
            ],
          ),
        ),

        // ── Firm footer strip ──────────────────────────────────
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: brand.primary.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Text(
                brand.firmName.isNotEmpty ? brand.firmName : 'Survey Report',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: brand.primary,
                ),
              ),
              if (brand.firmEmail.isNotEmpty) ...[
                const Text('  ·  ',
                    style: TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
                Text(brand.firmEmail,
                    style:
                        const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _today() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _CoverInfoBlock extends StatelessWidget {
  const _CoverInfoBlock({
    required this.label,
    required this.value,
    required this.brand,
  });
  final String label;
  final String value;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: brand.secondary,
            )),
        Text(
          value.isNotEmpty ? value : '—',
          style: TextStyle(fontSize: 9, color: brand.bodyText),
        ),
      ],
    );
  }
}

// ── Summary page content (page 2) ─────────────────────────────────────────

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.section,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final ReportSection section;
  final _Brand brand;
  final String headerLeft;
  final String headerRight;
  final int pageNum;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RunningHeader(left: headerLeft, right: headerRight, brand: brand),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent page-2 heading
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: brand.primary, width: 2.5),
                      ),
                    ),
                    child: Text(
                      'EXECUTIVE SUMMARY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: brand.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionBody(section: section, brand: brand),
                ],
              ),
            ),
          ),
        ),
        _PageFooter(brand: brand, pageNum: pageNum, totalPages: totalPages),
      ],
    );
  }
}

// ── TOC page content ───────────────────────────────────────────────────────

class _TocContent extends StatelessWidget {
  const _TocContent({
    required this.entries,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final List<_TocEntry> entries;
  final _Brand brand;
  final String headerLeft;
  final String headerRight;
  final int pageNum;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RunningHeader(left: headerLeft, right: headerRight, brand: brand),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: brand.primary, width: 1.5),
                    ),
                  ),
                  child: Text(
                    'TABLE OF CONTENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: brand.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Entries — each indented ~2 cm from the content left edge
                ...entries.map((e) => _TocRow(entry: e, brand: brand)),
              ],
            ),
          ),
        ),
        _PageFooter(brand: brand, pageNum: pageNum, totalPages: totalPages),
      ],
    );
  }
}

// ── TOC row ────────────────────────────────────────────────────────────────

// _TocRow uses a single CustomPainter so layout is pixel-exact:
// title measured then drawn left, page number measured then drawn right,
// dot leader drawn between the two. No Row flex arithmetic involved.

class _TocRow extends StatelessWidget {
  const _TocRow({required this.entry, required this.brand});
  final _TocEntry entry;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // width: double.infinity ensures the SizedBox fills the Column's cross-axis
      // width; without it the SizedBox defaults to 0 and the painter gets size.width=0.
      child: SizedBox(
        width: double.infinity,
        height: 20,
        child: CustomPaint(
          painter: _TocLinePainter(
            title: entry.title,
            page: '${entry.page}',
            textColor: brand.bodyText,
            dotColor: brand.subtleText,
          ),
        ),
      ),
    );
  }
}

class _TocLinePainter extends CustomPainter {
  const _TocLinePainter({
    required this.title,
    required this.page,
    required this.textColor,
    required this.dotColor,
  });

  final String title;
  final String page;
  final Color textColor;
  final Color dotColor;

  static const double _fontSize = 9.5;
  static const double _dotGap = 5.0; // gap between text and first/last dot
  static const double _dotSpace = 4.0; // centre-to-centre dot spacing
  static const double _dotR = 0.8; // dot radius

  TextStyle get _style =>
      TextStyle(fontSize: _fontSize, color: textColor, height: 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 10) return; // nothing meaningful to draw

    // ── Measure page number ──────────────────────────────────────────────
    final pageTp = TextPainter(
      text: TextSpan(text: page, style: _style),
      textDirection: TextDirection.ltr,
    )..layout();

    final pageLeft = size.width - pageTp.width; // right-align to canvas edge
    final textTop = (size.height - pageTp.height) / 2;

    // ── Measure title (capped so it cannot overlap the page number) ──────
    final maxTitleW = (pageLeft - _dotGap * 2 - 4).clamp(0.0, size.width);
    final titleTp = TextPainter(
      text: TextSpan(text: title, style: _style),
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    )..layout(maxWidth: maxTitleW);

    // ── Draw title ───────────────────────────────────────────────────────
    titleTp.paint(canvas, Offset(0, textTop));

    // ── Draw page number ─────────────────────────────────────────────────
    pageTp.paint(canvas, Offset(pageLeft, textTop));

    // ── Draw dot leader between title end and page number start ──────────
    final x0 = titleTp.width + _dotGap;
    final x1 = pageLeft - _dotGap;
    if (x1 > x0 + _dotSpace) {
      final paint = Paint()..color = dotColor.withValues(alpha: 0.4);
      final dotY = size.height / 2;
      var x = x0 + _dotSpace / 2;
      while (x < x1) {
        canvas.drawCircle(Offset(x, dotY), _dotR, paint);
        x += _dotSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_TocLinePainter old) =>
      old.title != title ||
      old.page != page ||
      old.textColor != textColor ||
      old.dotColor != dotColor;
}

// ── Body pages — multiple sections flowing on the same A4 page ────────────

class _MultiSectionBodyContent extends StatelessWidget {
  const _MultiSectionBodyContent({
    required this.sections,
    required this.sectionNumbers,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final List<ReportSection> sections;
  final List<int?> sectionNumbers; // parallel to sections
  final _Brand brand;
  final String headerLeft;
  final String headerRight;
  final int pageNum;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RunningHeader(left: headerLeft, right: headerRight, brand: brand),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                _SectionContent(
                  section: sections[i],
                  sectionNumber:
                      i < sectionNumbers.length ? sectionNumbers[i] : null,
                  brand: brand,
                ),
              ],
            ],
          ),
        ),
        _PageFooter(brand: brand, pageNum: pageNum, totalPages: totalPages),
      ],
    );
  }
}

// ── Running header ────────────────────────────────────────────────────────

class _RunningHeader extends StatelessWidget {
  const _RunningHeader({
    required this.left,
    required this.right,
    required this.brand,
  });

  final String left;
  final String right;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 6),
          child: Row(
            children: [
              Text(
                left,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: brand.bodyText,
                ),
              ),
              const Spacer(),
              Text(
                right,
                style: TextStyle(
                  fontSize: 8,
                  fontStyle: FontStyle.italic,
                  color: brand.secondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          color: brand.primary,
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

// ── Page footer with page number ──────────────────────────────────────────

class _PageFooter extends StatelessWidget {
  const _PageFooter({
    required this.brand,
    this.pageNum,
    this.totalPages,
  });
  final _Brand brand;
  final int? pageNum;
  final int? totalPages;

  @override
  Widget build(BuildContext context) {
    final notice = brand.firmName.isNotEmpty
        ? 'This report is supplied without prejudice. Confidential — ${brand.firmName}'
        : 'This report is supplied without prejudice. Confidential.';

    final pgText = pageNum != null
        ? (totalPages != null
            ? 'Page $pageNum of $totalPages'
            : 'Page $pageNum')
        : null;

    return Column(
      children: [
        Container(
          height: 0.75,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          color: const Color(0xFFCCCCCC),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  notice,
                  style: const TextStyle(fontSize: 7, color: Color(0xFF757575)),
                ),
              ),
              if (pgText != null) ...[
                const SizedBox(width: 12),
                Text(
                  pgText,
                  style: const TextStyle(
                    fontSize: 7,
                    color: Color(0xFF757575),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section content ───────────────────────────────────────────────────────

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    required this.section,
    required this.brand,
    this.sectionNumber,
  });
  final ReportSection section;
  final _Brand brand;
  final int? sectionNumber;

  @override
  Widget build(BuildContext context) {
    final displayTitle = sectionNumber != null
        ? '$sectionNumber.  ${section.title}'
        : section.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading with primary-colour bottom rule — mirrors OOXML Heading2 style
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: brand.primary, width: 1.5),
            ),
          ),
          child: Text(
            displayTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: brand.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Locked clauses get a tinted accent background
        if (section.isLocked)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brand.accent,
              border: Border.all(color: brand.primary.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: _SectionBody(section: section, brand: brand),
          )
        else
          _SectionBody(section: section, brand: brand),
      ],
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, required this.brand});
  final ReportSection section;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    if (section.content.isEmpty) {
      return Text(
        '[${section.title} — not yet completed]',
        style: const TextStyle(
          fontSize: 9.5,
          color: Color(0xFF9CA3AF),
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      );
    }

    final paragraphs = splitSectionParagraphs(section.content);

    if (paragraphs.length <= 1) {
      final lines =
          section.content.split('\n').map((l) => l.trimRight()).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final isBullet = line.trimLeft().startsWith('•') ||
              line.trimLeft().startsWith('  •');
          return Padding(
            padding: EdgeInsets.only(bottom: 2, left: isBullet ? 8 : 0),
            child: Text(
              line,
              style:
                  TextStyle(fontSize: 9.5, color: brand.bodyText, height: 1.55),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs
          .map((para) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(para,
                    style: TextStyle(
                        fontSize: 9.5, color: brand.bodyText, height: 1.6)),
              ))
          .toList(),
    );
  }
}
