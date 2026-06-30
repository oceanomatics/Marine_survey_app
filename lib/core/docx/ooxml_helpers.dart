// lib/core/docx/ooxml_helpers.dart
// Part of lib/core/docx/docx_builder.dart — shares the same library namespace.

part of 'docx_builder.dart';

// ── Types ──────────────────────────────────────────────────────────────────

enum WAlignment { left, center, right, justify }

class _Img {
  const _Img({required this.rid, required this.bytes, required this.ext});
  final String rid;
  final Uint8List bytes;
  final String ext;
}

class _HeaderData {
  const _HeaderData({required this.leftText, required this.rightText});
  final String leftText;
  final String rightText;
}

// ── XML escaping ───────────────────────────────────────────────────────────

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _t(String text) {
  final escaped = _x(text);
  final needsPreserve = text.startsWith(' ') || text.endsWith(' ');
  return needsPreserve
      ? '<w:t xml:space="preserve">$escaped</w:t>'
      : '<w:t>$escaped</w:t>';
}

// ── Run properties ─────────────────────────────────────────────────────────

String _rPr({
  bool bold = false,
  bool italic = false,
  int? halfPtSize,
  String? colorHex,
}) {
  if (!bold && !italic && halfPtSize == null && colorHex == null) return '';
  final buf = StringBuffer('<w:rPr>');
  if (bold) buf.write('<w:b/>');
  if (italic) buf.write('<w:i/>');
  if (halfPtSize != null) buf.write('<w:sz w:val="$halfPtSize"/><w:szCs w:val="$halfPtSize"/>');
  if (colorHex != null) buf.write('<w:color w:val="$colorHex"/>');
  buf.write('</w:rPr>');
  return buf.toString();
}

// ── Paragraph ─────────────────────────────────────────────────────────────

String _para(
  String text, {
  String? styleId,
  bool bold = false,
  bool italic = false,
  int? halfPtSize,
  String? colorHex,
  WAlignment align = WAlignment.left,
  String? spacingAfterTwips,
}) {
  final buf = StringBuffer('<w:p>');
  // Paragraph properties
  final hasStyle = styleId != null;
  final hasAlign = align != WAlignment.left;
  final hasSpacing = spacingAfterTwips != null;
  if (hasStyle || hasAlign || hasSpacing) {
    buf.write('<w:pPr>');
    if (hasStyle) buf.write('<w:pStyle w:val="$styleId"/>');
    if (hasAlign) {
      final jc = switch (align) {
        WAlignment.center  => 'center',
        WAlignment.right   => 'right',
        WAlignment.justify => 'both',
        WAlignment.left    => 'left',
      };
      buf.write('<w:jc w:val="$jc"/>');
    }
    if (hasSpacing) buf.write('<w:spacing w:after="$spacingAfterTwips"/>');
    buf.write('</w:pPr>');
  }
  // Run
  if (text.isNotEmpty) {
    buf.write('<w:r>');
    buf.write(_rPr(bold: bold, italic: italic, halfPtSize: halfPtSize, colorHex: colorHex));
    buf.write(_t(text));
    buf.write('</w:r>');
  }
  buf.write('</w:p>');
  return buf.toString();
}

// ── Page break ─────────────────────────────────────────────────────────────

String _pageBreakPara() =>
    '<w:p><w:r><w:lastRenderedPageBreak/><w:br w:type="page"/></w:r></w:p>';

// ── Table ─────────────────────────────────────────────────────────────────

// colWidths in twips; if null, auto-size.
String _table(
  List<List<String>> rows, {
  bool boldFirstRow = false,
  List<int>? colWidths,
}) {
  final buf = StringBuffer();
  buf.write('<w:tbl>');
  buf.write('<w:tblPr>'
      '<w:tblStyle w:val="TableGrid"/>'
      '<w:tblW w:w="0" w:type="auto"/>'
      '<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" '
      'w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>'
      '</w:tblPr>');
  // Column widths
  if (colWidths != null) {
    buf.write('<w:tblGrid>');
    for (final w in colWidths) {
      buf.write('<w:gridCol w:w="$w"/>');
    }
    buf.write('</w:tblGrid>');
  }
  for (var r = 0; r < rows.length; r++) {
    final isHeader = r == 0 && boldFirstRow;
    buf.write('<w:tr>');
    if (isHeader) {
      buf.write('<w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>');
    } else {
      buf.write('<w:trPr><w:cantSplit/></w:trPr>');
    }
    for (var c = 0; c < rows[r].length; c++) {
      buf.write('<w:tc>');
      if (colWidths != null && c < colWidths.length) {
        buf.write('<w:tcPr>'
            '<w:tcW w:w="${colWidths[c]}" w:type="dxa"/>'
            '</w:tcPr>');
      }
      buf.write(_para(rows[r][c], bold: isHeader, halfPtSize: isHeader ? 20 : 18));
      buf.write('</w:tc>');
    }
    buf.write('</w:tr>');
  }
  buf.write('</w:tbl>');
  return buf.toString();
}

// ── Inline image ───────────────────────────────────────────────────────────

String _inlineImage(String rid, int drawId, int cx, int cy) => '''
<w:p><w:r><w:drawing>
<wp:inline distT="0" distB="0" distL="0" distR="0"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
  <wp:extent cx="$cx" cy="$cy"/>
  <wp:docPr id="$drawId" name="Image$drawId"/>
  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr>
          <pic:cNvPr id="$drawId" name="Image$drawId"/>
          <pic:cNvPicPr/>
        </pic:nvPicPr>
        <pic:blipFill>
          <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            r:embed="$rid"/>
          <a:stretch><a:fillRect/></a:stretch>
        </pic:blipFill>
        <pic:spPr>
          <a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </pic:spPr>
      </pic:pic>
    </a:graphicData>
  </a:graphic>
</wp:inline>
</w:drawing></w:r></w:p>''';

// ── Shaded block (full-width coloured band) ───────────────────────────────

/// A full-width single-cell table with a solid background colour — used for
/// the cover page vessel-name band and report-type band.
String _shadedBlock(
  String text, {
  required String bgHex,
  String textHex = 'FFFFFF',
  int halfPtSize = 40,
  WAlignment align = WAlignment.center,
  int paddingTwips = 160,
}) {
  final jc = switch (align) {
    WAlignment.center  => 'center',
    WAlignment.right   => 'right',
    WAlignment.justify => 'both',
    WAlignment.left    => 'left',
  };
  final pad = paddingTwips.toString();
  final padH = (paddingTwips + 20).toString();
  return '<w:tbl>'
      '<w:tblPr>'
      '<w:tblW w:w="9355" w:type="dxa"/>'
      '<w:tblBorders>'
      '<w:top    w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:left   w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:right  w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '</w:tblBorders>'
      '</w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="9355"/></w:tblGrid>'
      '<w:tr>'
      '<w:trPr><w:cantSplit/></w:trPr>'
      '<w:tc>'
      '<w:tcPr>'
      '<w:tcW w:w="9355" w:type="dxa"/>'
      '<w:shd w:val="clear" w:color="auto" w:fill="$bgHex"/>'
      '<w:tcMar>'
      '<w:top    w:w="$pad"  w:type="dxa"/>'
      '<w:left   w:w="$padH" w:type="dxa"/>'
      '<w:bottom w:w="$pad"  w:type="dxa"/>'
      '<w:right  w:w="$padH" w:type="dxa"/>'
      '</w:tcMar>'
      '</w:tcPr>'
      '<w:p>'
      '<w:pPr>'
      '<w:jc w:val="$jc"/>'
      '<w:spacing w:before="0" w:after="0"/>'
      '</w:pPr>'
      '<w:r>'
      '<w:rPr>'
      '<w:b/>'
      '<w:sz w:val="$halfPtSize"/><w:szCs w:val="$halfPtSize"/>'
      '<w:color w:val="$textHex"/>'
      '</w:rPr>'
      '${_t(text)}'
      '</w:r>'
      '</w:p>'
      '</w:tc>'
      '</w:tr>'
      '</w:tbl>';
}

// ── Sign-off block ────────────────────────────────────────────────────────

/// Two-column authentication table: Attending Surveyor | Reviewing Surveyor.
/// Each cell carries: role label, name, date signed, and a signature line.
/// [attendingName]/[reviewingName] are null when that party has not yet signed.
String _signOffTableXml({
  String? attendingName,
  String? attendingDate,
  String? reviewingName,
  String? reviewingDate,
}) {
  // A4 body width 9026 twips; split evenly with a narrow gutter.
  const colW = 4413; // ~half, leaving 200 twips for border spacing

  String cell(String role, String? name, String? date) {
    final buf = StringBuffer();
    buf.write('<w:tc>');
    buf.write('<w:tcPr>'
        '<w:tcW w:w="$colW" w:type="dxa"/>'
        '<w:tcBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>'
        '</w:tcBorders>'
        '<w:tcMar>'
        '<w:top w:w="120" w:type="dxa"/>'
        '<w:left w:w="140" w:type="dxa"/>'
        '<w:bottom w:w="120" w:type="dxa"/>'
        '<w:right w:w="140" w:type="dxa"/>'
        '</w:tcMar>'
        '</w:tcPr>');
    // Role label
    buf.write(_para(role,
        bold: true, halfPtSize: 20, colorHex: '1E3A5F'));
    // Name
    buf.write(_para(
        name != null ? 'Name:  $name' : 'Name:  —',
        halfPtSize: 20, colorHex: '374151'));
    // Date
    buf.write(_para(
        date != null ? 'Date:   $date' : 'Date:   —',
        halfPtSize: 20, colorHex: '374151'));
    // Signature line
    buf.write(_para('Signature:', halfPtSize: 20, colorHex: '374151'));
    buf.write(_para(' ', halfPtSize: 28)); // blank line for ink sig
    buf.write('</w:tc>');
    return buf.toString();
  }

  return '<w:tbl>'
      '<w:tblPr>'
      '<w:tblW w:w="9026" w:type="dxa"/>'
      '<w:tblBorders>'
      '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>'
      '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>'
      '</w:tblBorders>'
      '</w:tblPr>'
      '<w:tblGrid>'
      '<w:gridCol w:w="$colW"/>'
      '<w:gridCol w:w="$colW"/>'
      '</w:tblGrid>'
      '<w:tr>'
      '${cell('ATTENDING SURVEYOR', attendingName, attendingDate)}'
      '${cell('REVIEWING SURVEYOR', reviewingName, reviewingDate)}'
      '</w:tr>'
      '</w:tbl>';
}

// ── Header XML ────────────────────────────────────────────────────────────

/// Running header for body pages (page 2+).
/// Left: [leftText] (firm name). Right (tab-aligned): [rightText] (vessel/ref).
/// A thin rule below separates it from the body text.
String _bodyHeaderXml(String leftText, String rightText) {
  const rPrLeft = '<w:rPr>'
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>'
      '<w:b/>'
      '<w:sz w:val="18"/><w:szCs w:val="18"/>'
      '<w:color w:val="374151"/>'
      '</w:rPr>';
  const rPrRight = '<w:rPr>'
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>'
      '<w:sz w:val="18"/><w:szCs w:val="18"/>'
      '<w:color w:val="6B7280"/>'
      '</w:rPr>';
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:hdr'
      ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
      ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:p>'
      '<w:pPr>'
      '<w:tabs><w:tab w:val="right" w:pos="9355"/></w:tabs>'
      '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="D1D5DB"/></w:pBdr>'
      '<w:spacing w:before="0" w:after="80"/>'
      '</w:pPr>'
      '<w:r>$rPrLeft${_t(leftText)}</w:r>'
      '<w:r>$rPrRight<w:tab/>${_t(rightText)}</w:r>'
      '</w:p>'
      '</w:hdr>';
}

/// Empty first-page header — suppresses the running header on the cover page.
const String _emptyHeaderXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:hdr'
    ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
    ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:p>'
    '</w:hdr>';

// ── document.xml wrapper ───────────────────────────────────────────────────

String _wrapDocument(String body, {bool hasFooter = false, bool hasHeader = false}) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document'
    ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
    ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:body>'
    '$body'
    '<w:sectPr>'
    // Header: first page = empty (cover), default = firm name + vessel/ref
    '${hasHeader ? '<w:headerReference w:type="first" r:id="rId_header_first"/>'
                   '<w:headerReference w:type="default" r:id="rId_header_body"/>' : ''}'
    // Footer on all pages (first-page ref needed when titlePg is set)
    '${hasFooter && hasHeader ? '<w:footerReference w:type="first" r:id="rId_footer"/>' : ''}'
    '${hasFooter ? '<w:footerReference w:type="default" r:id="rId_footer"/>' : ''}'
    // titlePg enables the separate first-page header
    '${hasHeader ? '<w:titlePg/>' : ''}'
    '<w:pgSz w:w="11906" w:h="16838"/>'
    '<w:pgMar w:top="1440" w:right="1440" w:bottom="1134" w:left="1440"'
    ' w:header="709" w:footer="709" w:gutter="0"/>'
    '</w:sectPr>'
    '</w:body>'
    '</w:document>';

/// WP footer: notice text + "Page N of Total" centred in small grey type.
String _footerXml(String wpText) {
  final escaped = wpText
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  const rpr = '<w:rPr>'
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>'
      '<w:sz w:val="14"/>'
      '<w:szCs w:val="14"/>'
      '<w:color w:val="9CA3AF"/>'
      '</w:rPr>';
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:ftr'
      ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
      ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:p>'
      '<w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="0"/></w:pPr>'
      // WP text
      '<w:r>$rpr<w:t xml:space="preserve">$escaped — Page </w:t></w:r>'
      // PAGE field
      '<w:r>$rpr<w:fldChar w:fldCharType="begin"/></w:r>'
      '<w:r>$rpr<w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
      '<w:r>$rpr<w:fldChar w:fldCharType="separate"/></w:r>'
      '<w:r>$rpr<w:t>1</w:t></w:r>'
      '<w:r>$rpr<w:fldChar w:fldCharType="end"/></w:r>'
      // " of "
      '<w:r>$rpr<w:t xml:space="preserve"> of </w:t></w:r>'
      // NUMPAGES field
      '<w:r>$rpr<w:fldChar w:fldCharType="begin"/></w:r>'
      '<w:r>$rpr<w:instrText xml:space="preserve"> NUMPAGES </w:instrText></w:r>'
      '<w:r>$rpr<w:fldChar w:fldCharType="separate"/></w:r>'
      '<w:r>$rpr<w:t>1</w:t></w:r>'
      '<w:r>$rpr<w:fldChar w:fldCharType="end"/></w:r>'
      '</w:p>'
      '</w:ftr>';
}

// ── document.xml.rels ──────────────────────────────────────────────────────

const String _baseRels = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

String _documentRels(List<_Img> images, {bool hasFooter = false, bool hasHeader = false}) {
  final buf = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
  buf.write('<Relationship Id="rId1" Type="$_baseRels/styles" Target="styles.xml"/>');
  buf.write('<Relationship Id="rId2" Type="$_baseRels/settings" Target="settings.xml"/>');
  for (final img in images) {
    buf.write('<Relationship Id="${img.rid}" '
        'Type="$_baseRels/image" '
        'Target="media/${img.rid}.${img.ext}"/>');
  }
  if (hasFooter) {
    buf.write('<Relationship Id="rId_footer" '
        'Type="$_baseRels/footer" Target="footer1.xml"/>');
  }
  if (hasHeader) {
    buf.write('<Relationship Id="rId_header_first" '
        'Type="$_baseRels/header" Target="header1.xml"/>');
    buf.write('<Relationship Id="rId_header_body" '
        'Type="$_baseRels/header" Target="header2.xml"/>');
  }
  buf.write('</Relationships>');
  return buf.toString();
}

// ── _rels/.rels ────────────────────────────────────────────────────────────

const String _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="word/document.xml"/>'
    '</Relationships>';

// ── [Content_Types].xml ────────────────────────────────────────────────────

String _contentTypes(List<_Img> images, {bool hasFooter = false, bool hasHeader = false}) {
  const footerCt =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml';
  const headerCt =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml';
  final buf = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>');
  final seenExts = <String>{};
  for (final img in images) {
    if (seenExts.add(img.ext)) {
      final ct = img.ext == 'png' ? 'image/png' : 'image/jpeg';
      buf.write('<Default Extension="${img.ext}" ContentType="$ct"/>');
    }
  }
  buf.write('<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>');
  buf.write('<Override PartName="/word/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>');
  buf.write('<Override PartName="/word/settings.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>');
  if (hasFooter) {
    buf.write('<Override PartName="/word/footer1.xml" ContentType="$footerCt"/>');
  }
  if (hasHeader) {
    buf.write('<Override PartName="/word/header1.xml" ContentType="$headerCt"/>');
    buf.write('<Override PartName="/word/header2.xml" ContentType="$headerCt"/>');
  }
  buf.write('</Types>');
  return buf.toString();
}

// ── styles.xml ─────────────────────────────────────────────────────────────

const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:color w:val="374151"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="120"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
      <w:color w:val="374151"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
      <w:keepNext/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="36"/>
      <w:szCs w:val="36"/>
      <w:color w:val="1F3A5F"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:spacing w:before="200" w:after="80"/>
      <w:keepNext/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="28"/>
      <w:szCs w:val="28"/>
      <w:color w:val="1F3A5F"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:spacing w:before="160" w:after="60"/>
      <w:keepNext/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="24"/>
      <w:szCs w:val="24"/>
      <w:color w:val="374151"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading4">
    <w:name w:val="heading 4"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:spacing w:before="120" w:after="40"/></w:pPr>
    <w:rPr>
      <w:b/>
      <w:i/>
      <w:sz w:val="22"/>
      <w:color w:val="374151"/>
    </w:rPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr>
      <w:tblBorders>
        <w:top    w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
        <w:left   w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
        <w:right  w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="D1D5DB"/>
      </w:tblBorders>
      <w:tblCellMar>
        <w:top    w:w="72" w:type="dxa"/>
        <w:left   w:w="108" w:type="dxa"/>
        <w:bottom w:w="72" w:type="dxa"/>
        <w:right  w:w="108" w:type="dxa"/>
      </w:tblCellMar>
    </w:tblPr>
  </w:style>
</w:styles>''';

// ── settings.xml ───────────────────────────────────────────────────────────

const String _settingsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:compat>
    <w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>
  </w:compat>
</w:settings>''';
