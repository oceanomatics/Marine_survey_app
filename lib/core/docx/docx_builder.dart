// lib/core/docx/docx_builder.dart
//
// Thin in-house OOXML builder. Produces valid .docx (Office Open XML) bytes
// without any external template dependency. Used by all report export flows.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

part 'ooxml_helpers.dart';

// ── Public API ─────────────────────────────────────────────────────────────

class DocxBuilder {
  final StringBuffer _body = StringBuffer();
  final List<_Img> _images = [];
  int _rId = 3; // rId1=styles, rId2=settings; images start at rId3
  int _drawId = 1;
  String? _footerWpText;
  _HeaderData? _bodyHeader;
  _Img? _headerLogo; // logo image stored in header2.xml; managed separately

  // Brand colours — set via setBranding(); fall back to neutral navy defaults
  String _primaryHex   = '1F3A5F';
  String _secondaryHex = '2C5282';
  String _accentHex    = 'EBF4FF';

  // A4 usable width at 2.54 cm margins ≈ 5 040 000 EMU (14 cm)
  static const int kPageWidthEmu = 5040000;

  /// Apply organisation branding. Call this before adding any content.
  /// All colour values may include or omit the leading '#'.
  void setBranding({
    required String primaryHex,
    required String secondaryHex,
    required String accentHex,
  }) {
    _primaryHex   = primaryHex.replaceAll('#', '');
    _secondaryHex = secondaryHex.replaceAll('#', '');
    _accentHex    = accentHex.replaceAll('#', '');
  }

  void addHeading(String text, int level) {
    assert(level >= 1 && level <= 4, 'Heading level must be 1–4');
    _body.write(_para(text, styleId: 'Heading$level'));
  }

  void addParagraph(
    String text, {
    bool bold = false,
    bool italic = false,
    int? halfPtSize,
    String? colorHex,
    WAlignment align = WAlignment.left,
  }) {
    _body.write(_para(text,
        bold: bold,
        italic: italic,
        halfPtSize: halfPtSize,
        colorHex: colorHex,
        align: align));
  }

  /// Empty paragraph — useful for vertical spacing.
  void addSpacer() => _body.write('<w:p/>');

  void addPageBreak() => _body.write(_pageBreakPara());

  /// [rows] is a list of rows; each row is a list of cell strings.
  /// [colWidths] in twips (1/1440 inch). A4 usable ≈ 9355 twips total.
  /// When [boldFirstRow] is true the first row gets the brand primary_colour
  /// background with white bold text (per spec §1.2.4).
  void addTable(
    List<List<String>> rows, {
    bool boldFirstRow = false,
    List<int>? colWidths,
  }) {
    _body.write(_table(
      rows,
      boldFirstRow: boldFirstRow,
      colWidths: colWidths,
      headerBgHex: boldFirstRow ? _primaryHex : null,
      altRowBgHex: _accentHex,
    ));
  }

  /// Sets the running page footer. [wpText] is the WP notice prefix;
  /// "Page N of Total" is appended automatically.
  void setFooter(String wpText) => _footerWpText = wpText;

  /// Sets the running header shown on body pages (page 2+).
  /// The cover page (page 1) gets an empty header via [w:titlePg].
  /// When [logoBytes] is provided the logo image replaces the text firm name.
  void setBodyHeader({
    required String leftText,
    required String rightText,
    Uint8List? logoBytes,
    String logoExt = 'png',
  }) {
    _bodyHeader = _HeaderData(
      leftText: leftText,
      rightText: rightText,
      logoBytes: logoBytes,
      logoExt: logoExt.toLowerCase(),
    );
    if (logoBytes != null) {
      _headerLogo = _Img(
          rid: _kHdrLogoRid,
          bytes: logoBytes,
          ext: logoExt.toLowerCase());
    }
  }

  /// Full-width coloured block — used for cover-page title and type bands.
  /// [bgHex] is the fill colour without the '#' prefix (e.g. `'1F3A5F'`).
  void addShadedBlock(
    String text, {
    required String bgHex,
    String textHex = 'FFFFFF',
    int halfPtSize = 40,
    WAlignment align = WAlignment.center,
    int paddingTwips = 160,
  }) {
    _body.write(_shadedBlock(
      text,
      bgHex: bgHex,
      textHex: textHex,
      halfPtSize: halfPtSize,
      align: align,
      paddingTwips: paddingTwips,
    ));
  }

  /// Two-column sign-off authentication table (Attending | Reviewing).
  /// Pass null for name/date when that party has not yet signed.
  void addSignOffBlock({
    String? attendingName,
    String? attendingDate,
    String? reviewingName,
    String? reviewingDate,
  }) {
    _body.write(_signOffTableXml(
      attendingName: attendingName,
      attendingDate: attendingDate,
      reviewingName: reviewingName,
      reviewingDate: reviewingDate,
      primaryHex: _primaryHex,
    ));
  }

  /// Adds an inline image. [widthEmu] defaults to full page width (14 cm).
  /// [heightEmu] defaults to maintaining a 4:3 ratio if not provided.
  void addImage(
    Uint8List bytes,
    String ext, {
    int widthEmu = kPageWidthEmu,
    int? heightEmu,
  }) {
    final h = heightEmu ?? (widthEmu * 3 ~/ 4);
    final rid = 'rId${_rId++}';
    _images.add(_Img(rid: rid, bytes: bytes, ext: ext.toLowerCase()));
    _body.write(_inlineImage(rid, _drawId++, widthEmu, h));
  }

  /// Builds and returns the raw .docx ZIP bytes.
  Uint8List build() {
    final archive = Archive();

    void addText(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    void addBin(String name, Uint8List bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final hasFooter = _footerWpText != null;
    final hasHeader = _bodyHeader != null;
    final hasLogo   = _headerLogo != null;
    addText('[Content_Types].xml',
        _contentTypes(_images, hasFooter: hasFooter, hasHeader: hasHeader,
            headerLogoExt: hasLogo ? _headerLogo!.ext : null));
    addText('_rels/.rels', _rootRels);
    addText('word/document.xml',
        _wrapDocument(_body.toString(), hasFooter: hasFooter, hasHeader: hasHeader));
    addText('word/_rels/document.xml.rels',
        _documentRels(_images, hasFooter: hasFooter, hasHeader: hasHeader));
    addText('word/styles.xml',
        _generateStylesXml(primaryHex: _primaryHex, secondaryHex: _secondaryHex));
    addText('word/settings.xml', _settingsXml);
    if (hasFooter) {
      addText('word/footer1.xml', _footerXml(_footerWpText!));
    }
    if (hasHeader) {
      addText('word/header1.xml', _emptyHeaderXml);
      addText('word/header2.xml',
          _bodyHeaderXml(
            _bodyHeader!.leftText,
            _bodyHeader!.rightText,
            logoBytes: _bodyHeader!.logoBytes,
            primaryHex: _primaryHex,
            secondaryHex: _secondaryHex,
          ));
      if (hasLogo) {
        addText('word/_rels/header2.xml.rels',
            _headerLogoRels(_headerLogo!.ext));
        addBin('word/media/$_kHdrLogoRid.${_headerLogo!.ext}',
            _headerLogo!.bytes);
      }
    }

    for (final img in _images) {
      addBin('word/media/${img.rid}.${img.ext}', img.bytes);
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }
}
