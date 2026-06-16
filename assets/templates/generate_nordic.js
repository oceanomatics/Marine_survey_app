// generate_nordic.js
// Generates template_nordic.docx matching the Nordic Insurers H&M Report format
// Structure based on completed MinRes Odin / MinRes Balder reports (Gard format)

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, BorderStyle, WidthType, ShadingType,
  VerticalAlign, PageNumber, SimpleField, LevelFormat, TabStopType, UnderlineType, PageBreak
} = require('docx');
const fs = require('fs');

const NAVY   = '002E5A';  // Nordic dark blue (from SVG logo)
const BLUE   = '185FA5';
const WHITE  = 'FFFFFF';
const LGREY  = 'F1EFE8';
const MGREY  = 'D3D1C7';
const W = 9360;

const border = (c = MGREY) => ({ style: BorderStyle.SINGLE, size: 4, color: c });
const allB = (c = MGREY) => ({ top: border(c), bottom: border(c), left: border(c), right: border(c) });
const noB  = () => ({ style: BorderStyle.NONE, size: 0, color: 'FFFFFF' });
const noAllB = () => ({ top: noB(), bottom: noB(), left: noB(), right: noB() });

const cell = (children, opts = {}) => new TableCell({
  children,
  borders: opts.borders ?? allB(),
  shading: opts.shading,
  width: opts.width ? { size: opts.width, type: WidthType.DXA } : undefined,
  margins: { top: 80, bottom: 80, left: 120, right: 120 },
  verticalAlign: opts.vAlign ?? VerticalAlign.TOP,
  columnSpan: opts.span,
});

const hdrCell = (text, width) => cell(
  [new Paragraph({ children: [new TextRun({ text, bold: true, size: 18, font: 'Calibri', color: WHITE })] })],
  { shading: { fill: NAVY, type: ShadingType.CLEAR }, width }
);

const p = (text, opts = {}) => new Paragraph({
  alignment: opts.align ?? AlignmentType.LEFT,
  spacing: { before: opts.before ?? 0, after: opts.after ?? 60 },
  children: [new TextRun({
    text: text ?? '',
    bold: opts.bold ?? false,
    italics: opts.italic ?? false,
    size: opts.size ?? 20,
    color: opts.color ?? '000000',
    font: 'Calibri',
  })]
});

const ph = (key, opts = {}) => p(`{{${key}}}`, opts);

const heading = (text) => new Paragraph({
  spacing: { before: 220, after: 80 },
  children: [new TextRun({ text, bold: true, size: 20, color: NAVY, font: 'Calibri' })]
});

const bullet = (text, opts = {}) => new Paragraph({
  spacing: { before: 0, after: 60 },
  indent: { left: 360, hanging: 200 },
  children: [new TextRun({ text: `\u2013  ${text}`, size: opts.size ?? 20, font: 'Calibri', italics: opts.italic ?? false })]
});

const rule = () => new Paragraph({
  spacing: { before: 120, after: 120 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: MGREY } },
  children: []
});

const spacer = (before = 100) => new Paragraph({ spacing: { before, after: 0 }, children: [] });

const labelVal = (label, placeholder) => new Paragraph({
  spacing: { before: 0, after: 40 },
  tabStops: [{ type: TabStopType.LEFT, position: 3400 }],
  children: [
    new TextRun({ text: label, size: 20, font: 'Calibri' }),
    new TextRun({ text: '\t', size: 20, font: 'Calibri' }),
    new TextRun({ text: `{{${placeholder}}}`, size: 20, font: 'Calibri' }),
  ]
});

// ══════════════════════════════════════════════════════════════════════════
// DOCUMENT
// ══════════════════════════════════════════════════════════════════════════
const doc = new Document({
  styles: {
    default: { document: { run: { font: 'Calibri', size: 20 } } }
  },
  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 },
        margin: { top: 1134, bottom: 1134, left: 1418, right: 1134 }
      }
    },

    // ── Header ─────────────────────────────────────────────────────────
    headers: {
      default: new Header({
        children: [
          new Table({
            width: { size: W, type: WidthType.DXA },
            columnWidths: [5400, 3960],
            rows: [new TableRow({ children: [
              cell([
                new Paragraph({ children: [
                  new TextRun({ text: '{{vessel_name}}', bold: true, size: 22, font: 'Calibri', color: NAVY }),
                  new TextRun({ text: '  \u2013  {{report_type}}{{sequence_no}}', size: 20, font: 'Calibri' }),
                ]}),
                p('{{job_number}}', { size: 18, color: '666666' }),
              ], { borders: noAllB(), width: 5400 }),
              cell([
                p('ABL Energy & Marine Consultants Ltd', { bold: true, size: 18, color: NAVY }),
                p('112 Robinson Road, #09-01', { size: 16, color: '666666' }),
                p('Singapore, 068902', { size: 16, color: '666666' }),
              ], { borders: noAllB(), width: 3960 }),
            ]})],
          }),
          rule(),
        ]
      })
    },

    // ── Footer ─────────────────────────────────────────────────────────
    footers: {
      default: new Footer({
        children: [
          rule(),
          new Paragraph({
            tabStops: [{ type: TabStopType.RIGHT, position: W }],
            children: [
              new TextRun({ text: 'Report No.: {{report_number}}', size: 16, font: 'Calibri', color: '666666' }),
              new TextRun({ text: '\tPage ', size: 16, font: 'Calibri', color: '666666' }),
              new SimpleField('PAGE', { size: 16, font: 'Calibri', color: '666666' }),
            ]
          })
        ]
      })
    },

    // ══ BODY ══════════════════════════════════════════════════════════════
    children: [

      // ── Reference table ────────────────────────────────────────────────
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [2200, 200, 6960],
        rows: [
          new TableRow({ children: [
            cell([p('Inst. Date', { size: 18 })],   { borders: noAllB(), width: 2200 }),
            cell([p(':', { size: 18 })],              { borders: noAllB(), width: 200 }),
            cell([ph('instruction_date', { size: 18 })], { borders: noAllB(), width: 6960 }),
          ]}),
          new TableRow({ children: [
            cell([p('Job No.', { size: 18 })],      { borders: noAllB(), width: 2200 }),
            cell([p(':', { size: 18 })],              { borders: noAllB(), width: 200 }),
            cell([ph('job_number', { size: 18, bold: true })], { borders: noAllB(), width: 6960 }),
          ]}),
          new TableRow({ children: [
            cell([p('Report No.', { size: 18 })],   { borders: noAllB(), width: 2200 }),
            cell([p(':', { size: 18 })],              { borders: noAllB(), width: 200 }),
            cell([ph('report_number', { size: 18, bold: true })], { borders: noAllB(), width: 6960 }),
          ]}),
          new TableRow({ children: [
            cell([p('Report Date', { size: 18 })],  { borders: noAllB(), width: 2200 }),
            cell([p(':', { size: 18 })],              { borders: noAllB(), width: 200 }),
            cell([ph('report_date', { size: 18, bold: true })], { borders: noAllB(), width: 6960 }),
          ]}),
        ]
      }),
      spacer(160),

      // ── Report type ────────────────────────────────────────────────────
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
        children: [new TextRun({ text: '{{report_type}}{{sequence_no}}', bold: true, size: 26, color: NAVY, font: 'Calibri' })]
      }),
      spacer(80),

      // ── INTRODUCTION ──────────────────────────────────────────────────
      heading('INTRODUCTION'),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [
          new TextRun({ text: 'THIS IS TO CERTIFY', bold: true, size: 20, font: 'Calibri' }),
          new TextRun({ text: ' that at the request of ', size: 20, font: 'Calibri' }),
          new TextRun({ text: '{{client_name}}', size: 20, font: 'Calibri' }),
          new TextRun({ text: ', being the Leading Hull & Machinery Underwriters of the subject vessel, the undersigned has on {{first_attendance_date}} and subsequent days surveyed the subject vessel whilst she was {{occurrence_location}}.', size: 20, font: 'Calibri' }),
        ]
      }),
      ph('opening_text'),

      // ── OCCURRENCE ────────────────────────────────────────────────────
      spacer(160),
      heading('OCCURRENCE'),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [
          new TextRun({ text: '{{occurrence_date}} \u2013 {{occurrence_title}}', bold: true, size: 20, font: 'Calibri' }),
        ]
      }),
      ph('occurrence_text'),

      // ── ATTENDING REPRESENTATIVES ─────────────────────────────────────
      spacer(160),
      heading('ATTENDING REPRESENTATIVES'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [4680, 4680],
        rows: [
          new TableRow({ children: [
            hdrCell('Name & Position', 4680),
            hdrCell('Representing', 4680),
          ]}),
          new TableRow({ children: [
            cell([ph('attendees_name_position')], { width: 4680 }),
            cell([ph('attendees_representing')],  { width: 4680 }),
          ]}),
        ]
      }),

      // ── VESSEL PARTICULARS ────────────────────────────────────────────
      spacer(160),
      heading('VESSEL PARTICULARS'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [3000, 6360],
        rows: [
          ...[
            ['Type',                 'vessel_type'],
            ['IMO Number',           'imo_number'],
            ['Gross Tonnage',        'gross_tonnage'],
            ['Flag',                 'flag'],
            ['Port of Registry',     'port_of_registry'],
            ['Built',                'year_built'],
            ['Build Yard',           'build_yard'],
            ['Owners',               'owners'],
            ['Operators',            'operators'],
            ['Class Society',        'class_society'],
            ['Class Notation',       'class_notation'],
            ['DOC Expiry',           'doc_expiry_date'],
            ['SMC Expiry',           'smc_expiry_date'],
            ['ISM Company',          'ism_company'],
            ['Length OA / BP',       'length_oa_bp'],
            ['Breadth / Depth',      'breadth_depth'],
            ['Maximum Draft',        'max_draft'],
            ['Deadweight',           'deadweight'],
            ['Service Speed',        'service_speed'],
          ].map(([label, key]) => new TableRow({ children: [
            cell([p(label, { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph(key, { size: 18 })], { width: 6360 }),
          ]}))
        ]
      }),

      // ── VESSEL'S MOVEMENTS & EVENTS ───────────────────────────────────
      spacer(160),
      heading("VESSEL\u2019S MOVEMENTS & EVENTS"),
      ph('movements_text'),

      // ── AVAILABLE INFORMATION ─────────────────────────────────────────
      spacer(160),
      heading('AVAILABLE INFORMATION'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [6360, 3000],
        rows: [
          new TableRow({ children: [
            hdrCell('Document', 6360),
            hdrCell('Enclosed / Available', 3000),
          ]}),
          new TableRow({ children: [
            cell([ph('available_doc_name')], { width: 6360 }),
            cell([ph('available_doc_status')], { width: 3000 }),
          ]}),
        ]
      }),

      // ── BRIEF TECHNICAL DESCRIPTION ───────────────────────────────────
      spacer(160),
      heading('BRIEF TECHNICAL DESCRIPTION'),
      ph('technical_description_text'),

      // ── BACKGROUND ────────────────────────────────────────────────────
      spacer(160),
      heading('BACKGROUND'),
      ph('background_text'),

      // ── DAMAGE DESCRIPTION ────────────────────────────────────────────
      spacer(160),
      heading('DAMAGE DESCRIPTION'),
      ph('damage_text'),

      // ── REPAIRS ───────────────────────────────────────────────────────
      spacer(160),
      heading('REPAIRS'),
      ph('repairs_text'),

      // ── OTHER MATTERS OF RELEVANCE ────────────────────────────────────
      spacer(160),
      heading('OTHER MATTERS OF RELEVANCE'),
      ph('other_matters_text'),

      // ── CAUSE CONSIDERATION ───────────────────────────────────────────
      spacer(160),
      heading('CAUSE CONSIDERATION'),
      ph('cause_text'),
      spacer(80),
      ph('allegation_text'),

      // ── REPAIR COST ───────────────────────────────────────────────────
      spacer(160),
      heading('REPAIR COST'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [2800, 1600, 1600, 1680, 1680],
        rows: [
          new TableRow({ children: [
            hdrCell('Supplier', 2800),
            hdrCell('Invoice No.', 1600),
            hdrCell('Date', 1600),
            hdrCell('Amount', 1680),
            hdrCell('Approved', 1680),
          ]}),
          new TableRow({ children: [
            cell([ph('repair_cost_supplier')], { width: 2800 }),
            cell([ph('repair_cost_invoice')],  { width: 1600 }),
            cell([ph('repair_cost_date')],     { width: 1600 }),
            cell([ph('repair_cost_amount')],   { width: 1680 }),
            cell([ph('repair_cost_approved')], { width: 1680 }),
          ]}),
          new TableRow({ children: [
            cell([p('TOTAL APPROVED WITHOUT PREJUDICE', { bold: true })],
              { span: 4, width: 7680 }),
            cell([ph('repair_cost_total', { bold: true })], { width: 1680 }),
          ]}),
        ]
      }),

      // ── DRY DOCKING / TEMPORARY / EXTRA EXPENSES ──────────────────────
      spacer(120),
      heading('DRY DOCKING / TEMPORARY REPAIRS'),
      ph('drydocking_text'),
      spacer(80),
      heading('EXTRA EXPENSES / GENERAL EXPENSES'),
      ph('extra_expenses_text'),

      // ── WORK NOT CONCERNING AVERAGE ───────────────────────────────────
      spacer(120),
      heading('WORK NOT CONCERNING AVERAGE'),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [new TextRun({
          text: 'The following items are not considered related to the casualty under review and are more appropriately for Owner\u2019s account:',
          size: 20, font: 'Calibri'
        })]
      }),
      ph('not_average_text'),

      // ── SUMMARY OF TIME FOR REPAIRS ────────────────────────────────────
      spacer(160),
      heading('SUMMARY OF TIME FOR REPAIRS'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [4680, 2340, 2340],
        rows: [
          new TableRow({ children: [
            hdrCell('', 4680),
            hdrCell('Dry Dock (days)', 2340),
            hdrCell('Afloat (days)', 2340),
          ]}),
          new TableRow({ children: [
            cell([p('Damage Repairs')], { width: 4680 }),
            cell([ph('repair_days_drydock')], { width: 2340 }),
            cell([ph('repair_days_afloat')],  { width: 2340 }),
          ]}),
          new TableRow({ children: [
            cell([p("Owner\u2019s Maintenance")], { width: 4680 }),
            cell([ph('owner_days_drydock')],  { width: 2340 }),
            cell([ph('owner_days_afloat')],   { width: 2340 }),
          ]}),
          new TableRow({ children: [
            cell([p('TOTAL', { bold: true })], { width: 4680 }),
            cell([ph('total_days_drydock', { bold: true })], { width: 2340 }),
            cell([ph('total_days_afloat', { bold: true })],  { width: 2340 }),
          ]}),
        ]
      }),

      // ── SIGNATURE BLOCK ────────────────────────────────────────────────
      spacer(240),
      rule(),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [4680, 4680],
        rows: [
          new TableRow({ children: [
            cell([p('ATTENDING SURVEYOR', { bold: true, color: NAVY })], { borders: noAllB(), width: 4680 }),
            cell([p('REVIEWED BY', { bold: true, color: NAVY })], { borders: noAllB(), width: 4680 }),
          ]}),
          new TableRow({ children: [
            cell([spacer(400), p('____________________________')], { borders: noAllB(), width: 4680 }),
            cell([spacer(400), p('____________________________')], { borders: noAllB(), width: 4680 }),
          ]}),
        ]
      }),

      // ── DISCLAIMER ────────────────────────────────────────────────────
      spacer(160),
      rule(),
      new Paragraph({
        spacing: { before: 80, after: 0 },
        children: [new TextRun({
          text: 'Subject to the rights of the Underwriters according to the relevant insurance conditions and policy. This report (including any enclosures and attachments) has been prepared for the exclusive use and benefit of the addressee(s) and solely for the purpose for which it is provided. Save to the extent provided for in the Company\u2019s Terms and Conditions or such other contract between the Company (or its affiliate) and the Client (or its affiliate) governing the issuance of this report, the Company assumes no liability to the addressee(s) for any claims, loss or damage whatsoever suffered by the addressee(s) as a result of any act, omission or default on the part of the Company or any of its servants, whether due to negligence or otherwise. No part of this report shall be reproduced, distributed or communicated to any third party without the prior written consent of the Company.',
          size: 16, font: 'Calibri', color: '666666', italics: true,
        })]
      }),

      // ── SELECTED PHOTOGRAPHS ──────────────────────────────────────────
      new Paragraph({ children: [new PageBreak()] }),
      heading('SELECTED PHOTOGRAPHS'),
      ph('photos_grid'),
    ]
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync('/home/claude/templates_build/template_nordic.docx', buf);
  console.log('✓ template_nordic.docx written (' + buf.length + ' bytes)');
});
