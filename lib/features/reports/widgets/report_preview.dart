// lib/features/reports/widgets/report_preview.dart
//
// WYSIWYG A4 report preview — mirrors the docx output visually.
// Page 1: Cover · Page 2: Executive Summary · Page 3: TOC · Pages 4+: flowing body

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../../../core/models/ai_generation_log_model.dart';
import '../utils/section_text.dart';
import '../utils/advice_summary_rows.dart';
import '../utils/annexure_groups.dart';
import '../utils/section_table_rows.dart';
import '../utils/page2_legal_text.dart';
import '../../photos/models/photo_model.dart';
import '../../photos/providers/photo_provider.dart';
import '../../../shared/widgets/drive_photo_image.dart';

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

    // Summary lives on page 2; body = everything else in §4.1 order.
    //
    // Omit-when-empty (TODO.md §1.9, general rule as of 9 July 2026 —
    // previously only applied to surveyorNotes/natureOfRepairs): a section
    // with nothing in it shouldn't render at all, rather than an empty or
    // near-empty block. Generalised to every section type EXCEPT the ones
    // below, which either must never be omitted (opening's certification
    // is mandatory; waiver/closing always resolve fallback text so are
    // never actually empty) or whose real content can live entirely in a
    // _trailingTables-rendered structured block from a *different* data
    // source than `content` (classStatutory: certs/conditions; causation:
    // third-party findings; informationSources: case documents;
    // repairs: WNCA cues) — content.isEmpty isn't a reliable "nothing
    // here" signal for those four, so they're left always-shown rather
    // than risk hiding real structured data. Revisit with a proper
    // per-type "has any content" check if that turns out to matter.
    const alwaysShow = {
      SectionType.opening,
      SectionType.waiver,
      SectionType.closing,
      SectionType.classStatutory,
      SectionType.causation,
      SectionType.informationSources,
      SectionType.repairs,
    };
    final summarySection = sections[SectionType.executiveSummary];
    final bodyTypes = oceanoSectionOrder
        .where((t) =>
            t != SectionType.executiveSummary &&
            sections.containsKey(t) &&
            (alwaysShow.contains(t) ||
                sections[t]!.fullContent.trim().isNotEmpty))
        .toList();
    final bodySections = bodyTypes.map((t) => sections[t]!).toList();

    // Page numbers for fixed pages
    final summaryPageNum = summarySection != null ? 2 : null;
    final tocPageNum = summarySection != null ? 3 : 2;
    final bodyStartPage = tocPageNum + 1;

    // Pagination — the page is always rendered at the same fixed true size
    // on every platform (see _kA4PreviewMaxWidth), never reflowed to the
    // screen width. That's what makes font sizes and pagination WYSIWYG-
    // identical across Android/web/desktop; the _ZoomableReportCanvas below
    // handles fitting it to whatever viewport is actually available via
    // pinch-zoom/pan instead of relayout.
    const pageW =
        _kA4PreviewMaxWidth - 32; // matches the content's 16px side padding
    const pageH = pageW * 297 / 210;
    const contentW = pageW - 56; // 28px margins each side within the page

    final bodyPages = _paginateSections(bodySections, pageH, contentW);
    final annexureGroups = buildAnnexureGroups(assembled.caseDocuments);
    final annexurePageCount =
        annexureGroups.length + (assembled.aiGenerationLog.isNotEmpty ? 1 : 0);
    final totalPages = bodyStartPage - 1 + bodyPages.length + annexurePageCount;
    final annexureStartPage = bodyStartPage + bodyPages.length;

    // Map each body section to its actual page number (for TOC accuracy)
    final sectionPages = <int>[];
    for (var gi = 0; gi < bodyPages.length; gi++) {
      for (var si = 0; si < bodyPages[gi].length; si++) {
        sectionPages.add(bodyStartPage + gi);
      }
    }

    // Section numbers parallel to bodyTypes / bodySections — computed as a
    // sequential 1-based position within the *actually-rendered* list
    // (TODO.md §1.9, 9 July 2026), not looked up from the static
    // oceanoSectionOrder index. oceanoSectionNumber() gave every section a
    // fixed index regardless of what else was omitted, so numbers left
    // gaps wherever an empty section was skipped (e.g. if item 14 was
    // omitted, item 15 still showed "15" instead of shifting to "14").
    // SectionType.closing (Disclaimer) is never numbered at all — TODO.md
    // row 73, it belongs at the very bottom as unnumbered back matter,
    // same as the sign-off block it now follows.
    var nextNumber = 1;
    final sectionNumbers = bodyTypes
        .map((t) => t == SectionType.closing ? null : nextNumber++)
        .toList();

    final tocEntries = List.generate(
      bodySections.length,
      (i) {
        final n = sectionNumbers[i];
        final title =
            n != null ? '$n.  ${bodySections[i].title}' : bodySections[i].title;
        return _TocEntry(title, sectionPages[i]);
      },
    )..addAll([
        for (final g in annexureGroups)
          _TocEntry('Annexure ${g.key}',
              annexureStartPage + annexureGroups.indexOf(g)),
        if (assembled.aiGenerationLog.isNotEmpty)
          _TocEntry('Annexure I — AI Generation Record',
              annexureStartPage + annexureGroups.length),
      ]);

    return ColoredBox(
      color: const Color(0xFFD0D0D0),
      child: _ZoomableReportCanvas(
        contentWidth: _kA4PreviewMaxWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
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
                    output: output,
                    assembled: assembled,
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
                        assembled: assembled,
                        brand: brand,
                        headerLeft: hLeft,
                        headerRight: hRight,
                        pageNum: bodyStartPage + e.key,
                        totalPages: totalPages,
                      ),
                    ),
                  )),

              // Annexures — one page per lettered group, then the AI
              // Generation Record last. Grouping logic shared with the docx
              // export via annexure_groups.dart.
              ...annexureGroups.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _A4Page(
                      fixed: false,
                      child: _AnnexureContent(
                        letter: e.value.key,
                        documents: e.value.value,
                        brand: brand,
                        headerLeft: hLeft,
                        headerRight: hRight,
                        pageNum: annexureStartPage + e.key,
                        totalPages: totalPages,
                      ),
                    ),
                  )),
              if (assembled.aiGenerationLog.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _A4Page(
                    fixed: false,
                    child: _AiGenerationRecordContent(
                      log: assembled.aiGenerationLog,
                      brand: brand,
                      headerLeft: hLeft,
                      headerRight: hRight,
                      pageNum: annexureStartPage + annexureGroups.length,
                      totalPages: totalPages,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Zoomable canvas ─────────────────────────────────────────────────────────
//
// The report page(s) are always laid out at one fixed true size (see
// _kA4PreviewMaxWidth) so fonts/graphics are pixel-identical on every
// platform — no more auto-reflow-to-screen-width, which was the actual
// cause of "looks smaller on web": the layout width changed per platform
// while font sizes stayed fixed absolute pixels. Instead this wraps the
// fixed-size content in an InteractiveViewer (pinch-zoom/pan, like a PDF
// viewer) and picks a sensible initial zoom to fit the viewport once.
class _ZoomableReportCanvas extends StatefulWidget {
  const _ZoomableReportCanvas({required this.child, required this.contentWidth});
  final Widget child;
  final double contentWidth;

  @override
  State<_ZoomableReportCanvas> createState() => _ZoomableReportCanvasState();
}

class _ZoomableReportCanvasState extends State<_ZoomableReportCanvas> {
  final _controller = TransformationController();
  bool _didInitialFit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Native only — web uses the plain-scroll path in build() below, which
    // doesn't need an initial-fit transform at all.
    if (!kIsWeb && !_didInitialFit) {
      final viewportW = MediaQuery.of(context).size.width;
      final scale = (viewportW / widget.contentWidth).clamp(0.1, 1.0);
      final dx =
          ((viewportW - widget.contentWidth * scale) / 2).clamp(0.0, double.infinity);
      _controller.value = Matrix4.identity()
        ..translateByDouble(dx, 16.0, 0.0, 1.0)
        ..scaleByDouble(scale, scale, scale, 1.0);
      _didInitialFit = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Native (Android/iOS): pinch-zoom/pan, like a PDF viewer — unchanged.
    if (!kIsWeb) {
      return InteractiveViewer(
        transformationController: _controller,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(600),
        minScale: 0.15,
        maxScale: 3.0,
        child: SizedBox(width: widget.contentWidth, child: widget.child),
      );
    }

    // Web: plain vertical mouse-wheel/trackpad scrolling reads much better
    // than InteractiveViewer's drag-to-pan/ctrl-scroll-to-zoom on desktop.
    // The fixed-size content (see the comment on this class) is scaled down
    // only when the browser window is narrower than the true page width —
    // on a normal-width desktop window scale is exactly 1 and this behaves
    // like plain unscaled scrolling, same as before the WYSIWYG-size fix.
    return LayoutBuilder(builder: (context, constraints) {
      final scale = constraints.maxWidth.isFinite
          ? (constraints.maxWidth / widget.contentWidth).clamp(0.1, 1.0)
          : 1.0;
      return SingleChildScrollView(
        child: Center(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: SizedBox(width: widget.contentWidth, child: widget.child),
          ),
        ),
      );
    });
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
              color: coverPhoto != null && coverPhoto!.hasUsablePhoto
                  ? Colors.white
                  : const Color(0xFFE5E7EB),
            ),
            clipBehavior: Clip.antiAlias,
            child: coverPhoto != null && coverPhoto!.hasUsablePhoto
                ? DrivePhotoImage(
                    photo: coverPhoto!,
                    preferThumbnail: false,
                    // Scale to fit, don't crop — cropping is a deliberate
                    // step done in the photo editor, not something the
                    // report preview/export should do automatically.
                    fit: BoxFit.contain,
                    noSourceBuilder: (_) => const Center(
                      child: Icon(Icons.directions_boat_outlined,
                          size: 48, color: Color(0xFF9CA3AF)),
                    ),
                    errorBuilder: (_) => const Center(
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
    required this.output,
    required this.assembled,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final ReportSection section;
  final ReportOutput output;
  final AssembledReportData assembled;
  final _Brand brand;
  final String headerLeft;
  final String headerRight;
  final int pageNum;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    // Page 2 order per surveyor direction (4 July 2026): title block
    // (tabular — spec's suggested-layout ASCII draws it as a bordered
    // box) → Advice Summary table → Legal Designations → AI Usage
    // Declaration (only if AI was used) → Document Control. The Advice
    // Summary table *is* the Executive Summary — the spec section is
    // literally titled "Section: Executive Summary (Advice Summary
    // Table)" — so there is no separate free-text block anywhere here.
    final vesselName = (assembled.vessel?['name'] as String?) ?? '';
    final assuredName = assembled.caseData['assured'] as String?;
    final reportTypeLabel = switch (output.outputType) {
      OutputType.advice => 'Advice No ${output.sequenceNo}',
      OutputType.preliminary => 'Preliminary Report',
      OutputType.final_ => 'Final Report',
    };
    final legal = buildLegalDesignationLines(assembled);
    final aiDeclaration = buildAiUsageDeclaration(assembled.aiGenerationLog);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RunningHeader(left: headerLeft, right: headerRight, brand: brand),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title block — Vessel Name / Assured / Report Type, as
                // one bordered table cell (tabular, matching the boxed
                // outline in the spec's suggested-layout ASCII).
                Table(
                  border:
                      TableBorder.all(color: Colors.grey.shade400, width: 0.75),
                  children: [
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            if (vesselName.isNotEmpty)
                              Text('M.V.  "$vesselName"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: brand.bodyText)),
                            if ((assuredName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('ASSURED: $assuredName',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11, color: brand.bodyText)),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${reportTypeLabel.toUpperCase()} SUMMARY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: brand.primary,
                                decoration: TextDecoration.underline,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 20),

                // (c) Advice Summary
                _AdviceSummaryTable(
                  rows: buildAdviceSummaryRows(output, assembled),
                  brand: brand,
                ),

                // Pushes Legal Designations / AI Usage Declaration down to
                // sit just above the footer, per surveyor direction (4 July
                // 2026), instead of flowing immediately under the table.
                const Spacer(),

                // (a) Legal Designations
                Text('LEGAL DESIGNATIONS',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: brand.primary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(legal.withoutPrejudice,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: brand.bodyText,
                        height: 1.5)),
                const SizedBox(height: 6),
                Text(legal.confidentiality,
                    style: TextStyle(
                        fontSize: 9, color: brand.bodyText, height: 1.5)),
                const SizedBox(height: 6),
                Text(legal.copyright,
                    style: TextStyle(
                        fontSize: 9, color: brand.bodyText, height: 1.5)),

                // (b) AI Usage Declaration — suppressed entirely when no
                // AI calls are on record (no surveyor toggle, per spec).
                if (aiDeclaration != null) ...[
                  const SizedBox(height: 16),
                  Text('AI USAGE DECLARATION',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: brand.primary,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(aiDeclaration,
                      style: TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: brand.bodyText,
                          height: 1.5)),
                ],
              ],
            ),
          ),
        ),
        _PageFooter(brand: brand, pageNum: pageNum, totalPages: totalPages),
      ],
    );
  }
}

// ── Advice Summary table (page 2, above the free-text narrative) ──────────

class _AdviceSummaryTable extends StatelessWidget {
  const _AdviceSummaryTable({required this.rows, required this.brand});

  final List<List<String>> rows;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ADVICE SUMMARY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: brand.primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        // Spec: "Full-width border on the outer table; horizontal rules
        // between rows only" — no vertical line between the label/content
        // columns, unlike the other register-style tables in this file.
        Table(
          border: TableBorder(
            top: BorderSide(color: Colors.grey.shade400, width: 0.75),
            bottom: BorderSide(color: Colors.grey.shade400, width: 0.75),
            left: BorderSide(color: Colors.grey.shade400, width: 0.75),
            right: BorderSide(color: Colors.grey.shade400, width: 0.75),
            horizontalInside:
                BorderSide(color: Colors.grey.shade300, width: 0.6),
          ),
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2.2)},
          children: rows
              .map((r) => TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(r[0],
                          style: const TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(r[1], style: const TextStyle(fontSize: 9.5)),
                    ),
                  ]))
              .toList(),
        ),
      ],
    );
  }
}

// ── Key:value table (spec §3 Vessel's Particulars — two columns, no outer
// border, compact line spacing) ────────────────────────────────────────────

class _KeyValueTable extends StatelessWidget {
  const _KeyValueTable({required this.rows, required this.brand});

  final List<List<String>> rows;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2.2)},
      children: rows
          .map((r) => TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r[0],
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: brand.bodyText)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r[1],
                      style: TextStyle(fontSize: 9.5, color: brand.bodyText)),
                ),
              ]))
          .toList(),
    );
  }
}

// ── Register table (formal listing with a bold header row — spec §2
// Attending Representatives, §5 Certificates / Conditions of Class) ────────

class _RegisterTable extends StatelessWidget {
  const _RegisterTable({required this.rows, required this.brand, this.columnFlex});

  /// First row is the header row.
  final List<List<String>> rows;
  final _Brand brand;
  /// Relative column widths (e.g. [1, 3, 1]) — defaults to equal flex for
  /// every column when omitted. TODO.md §1.8 S5: the Condition of Class
  /// table had equal widths regardless of content (Description needs far
  /// more room than Reference/Due Date); pass explicit weights there,
  /// leave every other table's default behaviour unchanged.
  final List<int>? columnFlex;

  @override
  Widget build(BuildContext context) {
    final header = rows.first;
    final body = rows.skip(1).toList();
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.6),
      columnWidths: {
        for (var i = 0; i < header.length; i++)
          i: FlexColumnWidth(
              (columnFlex != null && i < columnFlex!.length ? columnFlex![i] : 1)
                  .toDouble()),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: brand.accent),
          children: header
              .map((h) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(h,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: brand.primary)),
                  ))
              .toList(),
        ),
        ...body.map((r) => TableRow(children: [
              for (final cell in r)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(cell,
                      style: TextStyle(fontSize: 9, color: brand.bodyText)),
                ),
            ])),
      ],
    );
  }
}

// ── Attending Representatives — per-attendance blocks (spec §2) ───────────

class _AttendanceBlocksView extends StatelessWidget {
  const _AttendanceBlocksView({required this.blocks, required this.brand});

  final List<AttendanceBlock> blocks;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          if (blocks[i].label.isNotEmpty) ...[
            Text(blocks[i].label,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: brand.bodyText)),
            const SizedBox(height: 4),
          ],
          Text(blocks[i].introLine,
              style: TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: brand.subtleText)),
          const SizedBox(height: 4),
          if ((blocks[i].date ?? '').isNotEmpty)
            _AttendanceDetailLine('Date', blocks[i].date!, brand),
          if ((blocks[i].location ?? '').isNotEmpty)
            _AttendanceDetailLine('Location', blocks[i].location!, brand),
          if ((blocks[i].purpose ?? '').isNotEmpty)
            _AttendanceDetailLine('Purpose', blocks[i].purpose!, brand),
          const SizedBox(height: 6),
          _RegisterTable(rows: blocks[i].rows, brand: brand),
        ],
      ],
    );
  }
}

class _AttendanceDetailLine extends StatelessWidget {
  const _AttendanceDetailLine(this.label, this.value, this.brand);
  final String label;
  final String value;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 9, color: brand.bodyText),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

// ── Brief Technical Description — claim-object blocks (spec §5) ───────────
//
// Bordered box per claim object, key:value pairs inside — matches the
// spec's suggested layout more closely than a wide table would.

class _MachineryBlocksView extends StatelessWidget {
  const _MachineryBlocksView({required this.blocks, required this.brand});

  final List<MachineryBlock> blocks;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blocks[i].label,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: brand.primary)),
                const SizedBox(height: 6),
                _KeyValueTable(rows: blocks[i].rows, brand: brand),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Repair Costs — per-invoice summary (spec §11) ──────────────────────────

class _CostSummaryView extends StatelessWidget {
  const _CostSummaryView({
    required this.summaries,
    required this.totalsRows,
    required this.brand,
  });

  final List<AccountLineSummary> summaries;
  final List<List<String>> totalsRows;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < summaries.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(summaries[i].docLabel,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: brand.bodyText)),
          const SizedBox(height: 4),
          if (summaries[i].lineRows.isNotEmpty) ...[
            _RegisterTable(rows: summaries[i].lineRows, brand: brand),
            const SizedBox(height: 6),
          ],
          if (summaries[i].sumApprovedWp != null)
            Text(summaries[i].sumApprovedWp!,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: brand.bodyText)),
        ],
        if (totalsRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _KeyValueTable(rows: totalsRows, brand: brand),
        ],
      ],
    );
  }
}

// ── Waiver — sign-off block (spec §13) ─────────────────────────────────────

class _SignOffBlockView extends StatelessWidget {
  const _SignOffBlockView({required this.signOff, required this.brand});

  final ReportSignOff signOff;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    final today = () {
      final d = DateTime.now();
      const m = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${m[d.month]} ${d.year}';
    }();
    final style = TextStyle(fontSize: 9.5, color: brand.bodyText, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(today, style: style),
        const SizedBox(height: 10),
        Text('Yours faithfully', style: style),
        const SizedBox(height: 24),
        // Signature — no image plumbed through to the Preview tab yet
        // (docx export fetches it from Storage; Preview only reads local
        // photo files today), so a bracketed placeholder is shown here
        // per the "use placeholders when data is missing" instruction.
        Text(
          signOff.signatureStoragePath != null
              ? '[Signature on file]'
              : '[Signature not yet uploaded]',
          style: TextStyle(
              fontSize: 8.5,
              fontStyle: FontStyle.italic,
              color: brand.subtleText),
        ),
        const SizedBox(height: 4),
        Container(width: 160, height: 0.75, color: Colors.grey.shade400),
        const SizedBox(height: 4),
        Text(signOff.name, style: style.copyWith(fontWeight: FontWeight.w700)),
        if ((signOff.title ?? '').isNotEmpty)
          Text(signOff.title!, style: style),
        if ((signOff.company ?? '').isNotEmpty)
          Text(signOff.company!, style: style),
        if ((signOff.mobile ?? '').isNotEmpty)
          Text('Mob: ${signOff.mobile}', style: style),
        if ((signOff.email ?? '').isNotEmpty)
          Text('E: ${signOff.email}', style: style),
        if ((signOff.website ?? '').isNotEmpty)
          Text('W: ${signOff.website}', style: style),
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
    required this.assembled,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final List<ReportSection> sections;
  final List<int?> sectionNumbers; // parallel to sections
  final AssembledReportData assembled;
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
                  assembled: assembled,
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

// ── Annexure page content ──────────────────────────────────────────────────
//
// Per spec ("Preview Rendering of Annexures" in
// docs/report_builder_editor_notes.md): title page + document manifest
// (filename + date). Full document rendering / thumbnails deliberately not
// attempted here — the spec itself allows a manifest-only preview, with the
// document opened in the vault viewer on tap in a future pass.

class _AnnexureContent extends StatelessWidget {
  const _AnnexureContent({
    required this.letter,
    required this.documents,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final String letter;
  final List<Map<String, dynamic>> documents;
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
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'ANNEXURE $letter',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: brand.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (final d in documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 13, color: brand.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d['title'] as String? ?? 'Untitled',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                        Text(
                          _fmtDocDate(d['doc_date'] as String?),
                          style: const TextStyle(
                              fontSize: 9.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        _PageFooter(brand: brand, pageNum: pageNum, totalPages: totalPages),
      ],
    );
  }
}

String _fmtDocDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ── AI Generation Record (Annexure I) page content ─────────────────────────

class _AiGenerationRecordContent extends StatelessWidget {
  const _AiGenerationRecordContent({
    required this.log,
    required this.brand,
    required this.headerLeft,
    required this.headerRight,
    required this.pageNum,
    required this.totalPages,
  });

  final List<AiGenerationLogModel> log;
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
                  Center(
                    child: Text(
                      'ANNEXURE I — AI GENERATION RECORD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: brand.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(
                        color: Colors.grey.shade300, width: 0.6),
                    children: [
                      TableRow(children: [
                        for (final h in [
                          '#',
                          'Type',
                          'Section',
                          'Model',
                          'Reviewed'
                        ])
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: Text(h,
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                      for (final e in log.asMap().entries)
                        TableRow(children: [
                          _aiCell('${e.key + 1}'),
                          _aiCell(e.value.callType.replaceAll('_', ' ')),
                          _aiCell(e.value.sectionLabel?.replaceAll('_', ' ') ??
                              '—'),
                          _aiCell(e.value.model),
                          _aiCell(e.value.humanReviewed
                              ? (e.value.humanEdited ? 'Amended' : 'Accepted')
                              : 'Pending'),
                        ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _PageFooter(brand: brand, pageNum: pageNum, totalPages: totalPages),
      ],
    );
  }

  Widget _aiCell(String text) => Padding(
        padding: const EdgeInsets.all(5),
        child: Text(text, style: const TextStyle(fontSize: 9)),
      );
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
    required this.assembled,
    required this.brand,
    this.sectionNumber,
  });
  final ReportSection section;
  final AssembledReportData assembled;
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
            child: _SectionBody(
                section: section, assembled: assembled, brand: brand),
          )
        else
          _SectionBody(section: section, assembled: assembled, brand: brand),

        // Structured register that accompanies (not replaces) some sections'
        // free-text content — e.g. Certificates/Conditions of Class under
        // Class & Statutory Certification. Mirrors docx_export_service.dart.
        ..._trailingTables(section.type, assembled, brand),
      ],
    );
  }
}

/// Structured tables rendered alongside certain sections' free text, so the
/// Preview matches what the docx actually contains — see gap #11 in
/// docs/report_builder_editor_notes.md (Preview/docx renderer drift).
List<Widget> _trailingTables(
    SectionType type, AssembledReportData assembled, _Brand brand) {
  final widgets = <Widget>[];

  void heading(String text) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(Text(text,
        style: TextStyle(
            fontSize: 9.5, fontWeight: FontWeight.w700, color: brand.primary)));
    widgets.add(const SizedBox(height: 6));
  }

  switch (type) {
    case SectionType.classStatutory:
      final certRows = buildCertificateRows(assembled.certificates);
      if (certRows.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
        widgets.add(_RegisterTable(rows: certRows, brand: brand));
      }
      final ccRows = buildClassConditionRows(assembled.classConditions);
      if (ccRows.isNotEmpty) {
        heading('CONDITIONS OF CLASS');
        // Matches the docx export's [1800, 5700, 1855] ratio (~1:3:1).
        widgets.add(_RegisterTable(
            rows: ccRows, brand: brand, columnFlex: const [1, 3, 1]));
      }
      break;

    case SectionType.opening:
      // Spec §1 suggested layout — "Occurrence No. 1 | [date] | [title]"
      // table under the certifying paragraph. Supports multi-occurrence
      // cases (previously only ever `occurrences.first` was rendered).
      final occRows = buildOccurrenceRows(assembled.occurrences);
      if (occRows.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
        widgets.add(_RegisterTable(rows: occRows, brand: brand));
      }
      break;

    case SectionType.causation:
      // Spec §10 — third-party findings register + certainty level, shown
      // alongside (not replacing) the free-text narrative so voice
      // separation is visible as structured data, without fighting the
      // surveyor's ability to freely edit the generated prose.
      final tpRows = buildThirdPartyFindingRows(assembled.occurrences);
      if (tpRows.isNotEmpty) {
        heading('THIRD-PARTY FINDINGS');
        widgets.add(_RegisterTable(rows: tpRows, brand: brand));
      }
      final certainty = buildCertaintyLevelLabel(assembled.occurrences);
      if (certainty != null) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 9, color: brand.bodyText),
            children: [
              const TextSpan(
                  text: 'Certainty Level: ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: certainty),
            ],
          ),
        ));
      }
      break;

    case SectionType.informationSources:
      // Spec §12 — MINRES BALDER Document | Status table, the platform's
      // preferred default presentation over the flat bullet lists.
      final infoRows = buildAvailableInformationRows(
          assembled.caseDocuments, assembled.requestedDocuments);
      if (infoRows.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
        widgets.add(_RegisterTable(rows: infoRows, brand: brand));
      }
      // Spec §4 — Chronology of Events. Not a SectionType (auto-table, no
      // text section), so it was previously never rendered anywhere in the
      // Preview tab at all — attached here since informationSources (§6)
      // immediately precedes it (§7) in oceanoSectionOrder.
      final chronoRows = buildChronologyRows(assembled.timelineEvents);
      if (chronoRows.isNotEmpty) {
        heading('CHRONOLOGY OF EVENTS');
        widgets.add(_RegisterTable(rows: chronoRows, brand: brand));
      }
      break;

    case SectionType.repairs:
      // Spec §8.6 — Work Not Concerning Average: fixed locked opening
      // clause + bullet list, rendered only when WNCA items exist. Sourced
      // from context cues tagged CaseSection.notAverage
      // (docs/context_cue_system_review.md §3.1).
      final wncaItems = buildWncaItems(assembled.surveyorNotes);
      if (wncaItems.isNotEmpty) {
        heading('WORK NOT CONCERNING AVERAGE');
        widgets.add(Text(wncaOpeningClause,
            style:
                TextStyle(fontSize: 9.5, color: brand.bodyText, height: 1.5)));
        widgets.add(const SizedBox(height: 6));
        for (final item in wncaItems) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 3, left: 6),
            child: Text('•  $item',
                style: TextStyle(
                    fontSize: 9.5, color: brand.bodyText, height: 1.5)),
          ));
        }
      }
      break;

    case SectionType.waiver:
      // Spec §13 sign-off block — "Yours faithfully" + surveyor identity.
      // TODO.md row 73 (9 July 2026): moved here from SectionType.closing
      // — sign-off now follows Waiver directly, with Disclaimer (closing)
      // pushed to the very bottom of the document instead of sitting
      // between Waiver and the signature block.
      widgets.add(const SizedBox(height: 14));
      widgets.add(_SignOffBlockView(
          signOff: buildReportSignOff(assembled.organisation), brand: brand));
      break;

    default:
      break;
  }
  return widgets;
}

/// §2.18: appends the section's Remarks (the only free-text field left on
/// autoPopulatedSectionTypes) below its structured table, omitted entirely
/// when empty — matches docx_export_service.dart's renderRemarks convention.
Widget _withRemarks(Widget table, ReportSection section, _Brand brand) {
  final remarks = section.remarks?.trim();
  if (remarks == null || remarks.isEmpty) return table;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      table,
      const SizedBox(height: 8),
      Text('Remarks: $remarks',
          style: TextStyle(
              fontSize: 9.5,
              fontStyle: FontStyle.italic,
              color: brand.bodyText,
              height: 1.5)),
    ],
  );
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.assembled,
    required this.brand,
  });
  final ReportSection section;
  final AssembledReportData assembled;
  final _Brand brand;

  @override
  Widget build(BuildContext context) {
    // Structured layouts (spec §2 attendee register, §3 vessel particulars
    // two-column key:value) — built from the same underlying data as the
    // docx export instead of the section's free-text content, so Preview
    // and docx no longer drift apart on these sections (gap #11 in
    // docs/report_builder_editor_notes.md). Falls through to the generic
    // free-text rendering below if there's no structured data yet.
    if (section.type == SectionType.vesselParticulars) {
      final rows = buildVesselParticularsRows(assembled.vessel ?? {});
      if (rows.isNotEmpty) {
        return _withRemarks(
            _KeyValueTable(rows: rows, brand: brand), section, brand);
      }
    }
    if (section.type == SectionType.attendees) {
      final blocks =
          buildAttendanceBlocks(assembled.attendances, assembled.attendees);
      if (blocks.isNotEmpty) {
        return _withRemarks(
            _AttendanceBlocksView(blocks: blocks, brand: brand),
            section,
            brand);
      }
    }
    if (section.type == SectionType.machineryParticulars) {
      final blocks = buildMachineryBlocks(assembled.machinery);
      if (blocks.isNotEmpty) {
        return _withRemarks(
            _MachineryBlocksView(blocks: blocks, brand: brand),
            section,
            brand);
      }
    }
    if (section.type == SectionType.accounts) {
      final summaries = buildAccountSummaries(assembled);
      if (summaries.isNotEmpty) {
        return _withRemarks(
            _CostSummaryView(
              summaries: summaries,
              totalsRows: buildAccountTotalsRows(assembled),
              brand: brand,
            ),
            section,
            brand);
      }
    }
    // §2.18 (10 July 2026): previously these two fell through to the
    // generic free-text rendering below (plain `content` paragraphs) while
    // docx already built them as tables — a real drift, since whatever the
    // surveyor typed into the Editor's now-removed free-text box never
    // actually reached the export. Now shares the same row-builders as
    // docx_export_service.dart / the Editor's reference panel.
    if (section.type == SectionType.repairTimes) {
      final rows = buildRepairTimesRows(assembled.repairPeriods);
      if (rows.isNotEmpty) {
        return _withRemarks(
            _RegisterTable(rows: rows, brand: brand), section, brand);
      }
    }
    if (section.type == SectionType.documentsOnFile) {
      final rows = buildDocumentsOnFileRows(assembled.caseDocuments);
      if (rows.isNotEmpty) {
        return _withRemarks(
            _RegisterTable(rows: rows, brand: brand), section, brand);
      }
    }

    // fullContent seamlessly joins any carried-forward prior-report text
    // with this report's new delta (spec gap #10 — "no visible breaks" in
    // the rendered output); equals plain .content when there's nothing
    // carried forward.
    if (section.fullContent.isEmpty) {
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

    final paragraphs = splitSectionParagraphs(section.fullContent);

    if (paragraphs.length <= 1) {
      final lines =
          section.fullContent.split('\n').map((l) => l.trimRight()).toList();
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
