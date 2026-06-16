// generate_abl_template.js
// Generates template_abl.docx matching the London H&M Report format exactly
// All example content replaced with {{placeholders}}

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, BorderStyle, WidthType, ShadingType,
  VerticalAlign, PageNumber, SimpleField, LevelFormat, TabStopType, TabStopPosition,
  PageBreak, UnderlineType
} = require('docx');
const fs = require('fs');

// ── Colours ────────────────────────────────────────────────────────────────
const NAVY   = '0C2340';
const BLUE   = '185FA5';
const WHITE  = 'FFFFFF';
const LGREY  = 'F1EFE8';
const MGREY  = 'D3D1C7';

// ── Helpers ────────────────────────────────────────────────────────────────
const W  = 9360; // content width DXA (A4, 2.5cm margins each side)
const border = (color = MGREY) => ({ style: BorderStyle.SINGLE, size: 4, color });
const allBorders = (color = MGREY) => ({
  top: border(color), bottom: border(color),
  left: border(color), right: border(color)
});
const noBorder = () => ({ style: BorderStyle.NONE, size: 0, color: 'FFFFFF' });
const noAllBorders = () => ({
  top: noBorder(), bottom: noBorder(),
  left: noBorder(), right: noBorder()
});

const cell = (children, opts = {}) => new TableCell({
  children,
  borders: opts.borders ?? allBorders(),
  shading: opts.shading ?? undefined,
  width: opts.width ? { size: opts.width, type: WidthType.DXA } : undefined,
  margins: { top: 80, bottom: 80, left: 120, right: 120 },
  verticalAlign: opts.vAlign ?? VerticalAlign.TOP,
  columnSpan: opts.span,
});

const hdrCell = (text, width) => cell(
  [p(text, { bold: true, size: 18, color: WHITE })],
  { shading: { fill: NAVY, type: ShadingType.CLEAR }, width }
);

const p = (text, opts = {}) => new Paragraph({
  alignment: opts.align ?? AlignmentType.LEFT,
  spacing: { before: opts.before ?? 0, after: opts.after ?? 60 },
  children: [new TextRun({
    text: text ?? '',
    bold: opts.bold ?? false,
    italics: opts.italic ?? false,
    size: opts.size ?? 20, // 10pt = 20 half-points
    color: opts.color ?? '000000',
    font: 'Calibri',
    underline: opts.underline ? { type: UnderlineType.SINGLE } : undefined,
  })]
});

const ph = (placeholder, opts = {}) => p(`{{${placeholder}}}`, { ...opts, color: opts.color ?? '000000' });

const heading = (text) => new Paragraph({
  spacing: { before: 200, after: 80 },
  children: [new TextRun({
    text,
    bold: true,
    size: 20,
    color: NAVY,
    font: 'Calibri',
  })]
});

const bullet = (text) => new Paragraph({
  spacing: { before: 0, after: 60 },
  indent: { left: 360, hanging: 200 },
  children: [new TextRun({ text: `\u2013  ${text}`, size: 20, font: 'Calibri' })]
});

const rule = () => new Paragraph({
  spacing: { before: 120, after: 120 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: MGREY } },
  children: []
});

const spacer = (before = 100) => new Paragraph({
  spacing: { before, after: 0 }, children: []
});

// ── Two-col paragraph (label + value tab-stop) ─────────────────────────────
const labelVal = (label, placeholder) => new Paragraph({
  spacing: { before: 0, after: 40 },
  tabStops: [{ type: TabStopType.LEFT, position: 3200 }],
  children: [
    new TextRun({ text: label, size: 20, font: 'Calibri', bold: false }),
    new TextRun({ text: '\t-\t', size: 20, font: 'Calibri' }),
    new TextRun({ text: `{{${placeholder}}}`, size: 20, font: 'Calibri' }),
  ]
});

// ── Invoice table row ──────────────────────────────────────────────────────
const invoiceTable = (phPrefix) => new Table({
  width: { size: W, type: WidthType.DXA },
  columnWidths: [2200, 1800, 2500, 2860],
  rows: [
    new TableRow({ children: [
      hdrCell('Supplier / Invoice No.', 2200),
      hdrCell('Date', 1800),
      hdrCell('Currency & Amount', 2500),
      hdrCell('Approved Amount', 2860),
    ]}),
    new TableRow({ children: [
      cell([ph(`${phPrefix}_supplier`)], { width: 2200 }),
      cell([ph(`${phPrefix}_date`)], { width: 1800 }),
      cell([ph(`${phPrefix}_amount`)], { width: 2500 }),
      cell([ph(`${phPrefix}_approved`)], { width: 2860 }),
    ]}),
  ]
});

// ══════════════════════════════════════════════════════════════════════════
// DOCUMENT
// ══════════════════════════════════════════════════════════════════════════
const doc = new Document({
  styles: {
    default: {
      document: { run: { font: 'Calibri', size: 20 } }
    }
  },
  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 }, // A4
        margin: { top: 1134, bottom: 1134, left: 1418, right: 1134 } // ~2cm/2.5cm
      }
    },

    // ── Header ──────────────────────────────────────────────────────────
    headers: {
      default: new Header({
        children: [
          new Table({
            width: { size: W, type: WidthType.DXA },
            columnWidths: [5400, 3960],
            rows: [new TableRow({ children: [
              // Left: ship name + report title
              cell([
                new Paragraph({ children: [
                  new TextRun({ text: '{{vessel_name}}', bold: true, size: 22, font: 'Calibri', color: NAVY }),
                  new TextRun({ text: '  \u2013  {{report_type}}{{sequence_no}}', size: 20, font: 'Calibri' }),
                ]}),
                p('{{job_number}}', { size: 18, color: '666666' }),
              ], { borders: noAllBorders(), width: 5400 }),
              // Right: ABL address
              cell([
                p('ABL London Limited', { bold: true, size: 18, color: NAVY }),
                p('1st Floor, The Northern & Shell Building', { size: 16, color: '666666' }),
                p('10 Lower Thames Street', { size: 16, color: '666666' }),
                p('London, EC3R 6EN, U.K.', { size: 16, color: '666666' }),
              ], { borders: noAllBorders(), width: 3960 }),
            ]})],
          }),
          rule(),
        ]
      })
    },

    // ── Footer ──────────────────────────────────────────────────────────
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

      // ── Reference table ──────────────────────────────────────────────
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [2000, 200, 7160],
        rows: [
          new TableRow({ children: [
            cell([p('Inst. Date', { size: 18 })],  { borders: noAllBorders(), width: 2000 }),
            cell([p(':', { size: 18 })],             { borders: noAllBorders(), width: 200 }),
            cell([ph('instruction_date', { size: 18 })], { borders: noAllBorders(), width: 7160 }),
          ]}),
          new TableRow({ children: [
            cell([p('Job No.', { size: 18 })],     { borders: noAllBorders(), width: 2000 }),
            cell([p(':', { size: 18 })],             { borders: noAllBorders(), width: 200 }),
            cell([ph('job_number', { size: 18, bold: true })], { borders: noAllBorders(), width: 7160 }),
          ]}),
          new TableRow({ children: [
            cell([p('Report No.', { size: 18 })],  { borders: noAllBorders(), width: 2000 }),
            cell([p(':', { size: 18 })],             { borders: noAllBorders(), width: 200 }),
            cell([ph('report_number', { size: 18, bold: true })], { borders: noAllBorders(), width: 7160 }),
          ]}),
          new TableRow({ children: [
            cell([p('Report Date', { size: 18 })], { borders: noAllBorders(), width: 2000 }),
            cell([p(':', { size: 18 })],             { borders: noAllBorders(), width: 200 }),
            cell([ph('report_date', { size: 18, bold: true })], { borders: noAllBorders(), width: 7160 }),
          ]}),
        ]
      }),
      spacer(160),

      // ── Report type title ──────────────────────────────────────────────
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
        children: [new TextRun({ text: '{{report_type}}{{sequence_no}}', bold: true, size: 26, color: NAVY, font: 'Calibri' })]
      }),

      // ── Opening THIS IS TO CERTIFY ────────────────────────────────────
      spacer(120),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [
          new TextRun({ text: 'THIS IS TO CERTIFY', bold: true, size: 20, font: 'Calibri' }),
          new TextRun({ text: ' that at the request of ', size: 20, font: 'Calibri' }),
          new TextRun({ text: '{{client_name}}', size: 20, font: 'Calibri' }),
          new TextRun({ text: ', being the Leading Hull & Machinery Underwriters of the subject vessel, the undersigned attended:', size: 20, font: 'Calibri' }),
        ]
      }),
      spacer(80),
      new Paragraph({
        spacing: { before: 0, after: 60 },
        children: [
          new TextRun({ text: '{{vessel_type}}, {{propulsion_type}}: \u2013   ', size: 20, font: 'Calibri' }),
          new TextRun({ text: ' \u201c{{vessel_name}}\u201d', bold: true, size: 20, font: 'Calibri' }),
        ]
      }),
      new Paragraph({
        spacing: { before: 0, after: 60 },
        children: [
          new TextRun({ text: 'GT ', bold: true, size: 20, font: 'Calibri' }),
          new TextRun({ text: '{{gross_tonnage}}', bold: true, size: 20, font: 'Calibri' }),
          new TextRun({ text: ' of ', bold: true, size: 20, font: 'Calibri' }),
          new TextRun({ text: '{{flag}}', bold: true, size: 20, font: 'Calibri' }),
        ]
      }),
      new Paragraph({
        spacing: { before: 0, after: 60 },
        children: [
          new TextRun({ text: 'Where {{occurrence_location}}, {{occurrence_date}}.', size: 20, font: 'Calibri' }),
        ]
      }),
      spacer(60),
      ph('opening_text'),
      spacer(60),
      new Paragraph({
        spacing: { before: 0, after: 60 },
        children: [
          new TextRun({ text: 'DATE OF FIRST ATTENDANCE: ', bold: true, size: 20, font: 'Calibri' }),
          new TextRun({ text: '{{first_attendance_date}}', size: 20, font: 'Calibri' }),
        ]
      }),

      // ── ATTENDING THE SURVEY ──────────────────────────────────────────
      spacer(160),
      heading('ATTENDING THE SURVEY'),
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
            cell([ph('attendees_representing')], { width: 4680 }),
          ]}),
        ]
      }),

      // ── VESSEL'S DESCRIPTION ──────────────────────────────────────────
      spacer(160),
      heading("VESSEL\u2019S DESCRIPTION"),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [
          new TextRun({ text: '{{vessel_type_sentence}}', size: 20, font: 'Calibri' }),
          new TextRun({ text: ' It was built during {{year_built}} in {{build_country}} and has a loaded service speed of {{service_speed}} knots.', size: 20, font: 'Calibri' }),
        ]
      }),
      p('Principal Particulars', { bold: true }),
      labelVal('Owners', 'owners'),
      labelVal('Operators', 'operators'),
      labelVal('IMO Number', 'imo_number'),
      labelVal('Class', 'class_society'),
      labelVal('Flag & Port of Registry', 'flag_port'),
      spacer(80),
      p('Principal Dimensions', { bold: true }),
      labelVal('Length (OA) / (BP)', 'length_oa_bp'),
      labelVal('Breadth / Depth', 'breadth_depth'),
      labelVal('Maximum Draft', 'max_draft'),
      labelVal('Gross / Net Tonnage', 'gt_nt'),
      labelVal('Deadweight', 'deadweight'),
      spacer(80),
      ph('propulsion_block'),
      spacer(80),
      p('Class & Statutory Certification', { bold: true }),
      bullet('The vessel remains classed with {{class_society}}, Class Notation {{class_notation}}.'),
      bullet('Document of Compliance issued by {{doc_issuer}} on {{doc_issue_date}}, valid until {{doc_expiry_date}}.'),
      bullet('Safety Management Certificate issued by {{smc_issuer}} on {{smc_issue_date}}, valid until {{smc_expiry_date}}.'),
      bullet('{{ism_reported_text}}'),
      bullet('The Vessel was last drydocked at {{last_drydock_location}} in {{last_drydock_date}}.'),
      bullet('{{cert_notes}}'),

      // ── OCCURRENCE / CHRONOLOGY ───────────────────────────────────────
      spacer(160),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [
          new TextRun({ text: '{{occurrence_date}} \u2013 {{occurrence_title}}', bold: true, size: 20, font: 'Calibri' }),
        ]
      }),
      ph('occurrence_text'),
      spacer(80),
      ph('background_text'),

      // ── EXTENT OF DAMAGE ──────────────────────────────────────────────
      spacer(160),
      heading('EXTENT OF DAMAGE'),
      ph('damage_text'),
      spacer(80),

      // Machinery damage detail table
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [3000, 6360],
        rows: [
          new TableRow({ children: [
            cell([p('Make / Model', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_make_model', { size: 18 })], { width: 6360 }),
          ]}),
          new TableRow({ children: [
            cell([p('Type', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_type', { size: 18 })], { width: 6360 }),
          ]}),
          new TableRow({ children: [
            cell([p('Power Rating (MCR)', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_mcr', { size: 18 })], { width: 6360 }),
          ]}),
          new TableRow({ children: [
            cell([p('Serial No.', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_serial', { size: 18 })], { width: 6360 }),
          ]}),
          new TableRow({ children: [
            cell([p('Date of Manufacture', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_date_manufacture', { size: 18 })], { width: 6360 }),
          ]}),
          new TableRow({ children: [
            cell([p('Run Hrs Since New', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_hrs_new', { size: 18 })], { width: 6360 }),
          ]}),
          new TableRow({ children: [
            cell([p('Run Hrs Since Last Overhaul', { bold: true, size: 18 })],
              { shading: { fill: LGREY, type: ShadingType.CLEAR }, width: 3000 }),
            cell([ph('machinery_hrs_overhaul', { size: 18 })], { width: 6360 }),
          ]}),
        ]
      }),

      // ── ALLEGATION / CAUSATION ────────────────────────────────────────
      spacer(160),
      heading('ALLEGATION / CAUSATION'),
      ph('allegation_text'),
      spacer(80),
      heading('CAUSE CONSIDERATION'),
      ph('cause_text'),

      // ── REMARKS ───────────────────────────────────────────────────────
      spacer(120),
      heading('REMARKS'),
      ph('remarks_text'),

      // ── REPAIRS ───────────────────────────────────────────────────────
      spacer(120),
      heading('TEMPORARY REPAIRS CARRIED OUT'),
      ph('temporary_repairs_text'),
      spacer(80),
      heading('PERMANENT REPAIRS CARRIED OUT'),
      ph('permanent_repairs_text'),
      spacer(80),
      heading('STATUS OF REPAIRS'),
      ph('repair_status_text'),

      // ── GENERAL SERVICES & ACCESS ──────────────────────────────────────
      spacer(120),
      heading('GENERAL SERVICES & ACCESS'),
      ph('general_services_text'),

      // ── ESTIMATED COST ────────────────────────────────────────────────
      spacer(120),
      heading('ESTIMATED COST'),
      ph('estimated_cost_text'),

      // ── ACCOUNTS ──────────────────────────────────────────────────────
      spacer(120),
      heading('ACCOUNTS'),
      new Paragraph({
        spacing: { before: 0, after: 80 },
        children: [new TextRun({
          text: 'The accounts are approved by us subject to Underwriters\u2019 liability and adjustment in the usual manner being considered fair and reasonable as indicated below.',
          size: 20, font: 'Calibri'
        })]
      }),
      spacer(80),
      p('Repair Accounts', { bold: true }),
      invoiceTable('repair_invoice'),
      spacer(80),
      p('Dry-Dock Accounts', { bold: true }),
      invoiceTable('drydock_invoice'),
      spacer(80),

      // ── SUMMARY OF ACCOUNTS ───────────────────────────────────────────
      heading('SUMMARY OF ACCOUNTS'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [5400, 3960],
        rows: [
          new TableRow({ children: [
            hdrCell('Description', 5400),
            hdrCell('Amount', 3960),
          ]}),
          new TableRow({ children: [
            cell([ph('summary_description')], { width: 5400 }),
            cell([ph('summary_amount')], { width: 3960 }),
          ]}),
          new TableRow({ children: [
            cell([p('TOTAL APPROVED WITHOUT PREJUDICE', { bold: true })], { width: 5400 }),
            cell([ph('summary_total', { bold: true })], { width: 3960 }),
          ]}),
        ]
      }),

      // ── REPAIR TIMES ──────────────────────────────────────────────────
      spacer(120),
      heading('REPAIR TIMES'),
      ph('repair_times_text'),
      spacer(60),
      new Paragraph({
        spacing: { before: 0, after: 40 },
        tabStops: [
          { type: TabStopType.LEFT, position: 5040 },
          { type: TabStopType.LEFT, position: 7200 },
        ],
        children: [
          new TextRun({ text: '', font: 'Calibri', size: 20 }),
          new TextRun({ text: '\tDry Dock\tAlongside', bold: true, size: 20, font: 'Calibri' }),
        ]
      }),
      new Paragraph({
        spacing: { before: 0, after: 40 },
        tabStops: [
          { type: TabStopType.LEFT, position: 5040 },
          { type: TabStopType.LEFT, position: 7200 },
        ],
        children: [
          new TextRun({ text: 'Damage repairs', size: 20, font: 'Calibri' }),
          new TextRun({ text: '\t{{repair_days_drydock}} days\t{{repair_days_afloat}} days', size: 20, font: 'Calibri' }),
        ]
      }),
      new Paragraph({
        spacing: { before: 0, after: 40 },
        tabStops: [
          { type: TabStopType.LEFT, position: 5040 },
          { type: TabStopType.LEFT, position: 7200 },
        ],
        children: [
          new TextRun({ text: "Owner\u2019s repairs", size: 20, font: 'Calibri' }),
          new TextRun({ text: '\t{{owner_days_drydock}} days\t{{owner_days_afloat}} days', size: 20, font: 'Calibri' }),
        ]
      }),

      // ── SURVEYOR'S NOTES ──────────────────────────────────────────────
      spacer(120),
      heading("SURVEYOR\u2019S NOTES"),
      ph('surveyor_notes_text'),

      // ── PRINCIPAL DATES ───────────────────────────────────────────────
      spacer(120),
      heading('PRINCIPAL DATES'),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [2200, 1600, 5560],
        rows: [
          new TableRow({ children: [
            hdrCell('Date', 2200),
            hdrCell('Time', 1600),
            hdrCell('Comment', 5560),
          ]}),
          ...[0,1,2,3,4,5,6].map(() => new TableRow({ children: [
            cell([ph('principal_date')], { width: 2200 }),
            cell([ph('principal_time')], { width: 1600 }),
            cell([ph('principal_comment')], { width: 5560 }),
          ]})),
        ]
      }),

      // ── DOCUMENTS ─────────────────────────────────────────────────────
      spacer(120),
      heading('DOCUMENTS RETAINED ON FILE'),
      new Paragraph({
        spacing: { before: 0, after: 60 },
        children: [new TextRun({ text: 'Copies of the following documents are retained by us on file:', size: 20, font: 'Calibri' })]
      }),
      ph('documents_retained_text'),
      spacer(80),
      heading('DOCUMENTS REQUESTED'),
      new Paragraph({
        spacing: { before: 0, after: 60 },
        children: [new TextRun({ text: 'Copies of the following documents have been requested from the Owners:', size: 20, font: 'Calibri' })]
      }),
      ph('documents_requested_text'),

      // ── SIGNATURE BLOCK ───────────────────────────────────────────────
      spacer(240),
      rule(),
      new Table({
        width: { size: W, type: WidthType.DXA },
        columnWidths: [4680, 4680],
        rows: [
          new TableRow({ children: [
            cell([p('ATTENDING SURVEYOR', { bold: true, color: NAVY })],
              { borders: noAllBorders(), width: 4680 }),
            cell([p('REVIEWED BY', { bold: true, color: NAVY })],
              { borders: noAllBorders(), width: 4680 }),
          ]}),
          new TableRow({ children: [
            cell([spacer(400), p('____________________________')],
              { borders: noAllBorders(), width: 4680 }),
            cell([spacer(400), p('____________________________')],
              { borders: noAllBorders(), width: 4680 }),
          ]}),
        ]
      }),

      // ── APPENDED ──────────────────────────────────────────────────────
      spacer(120),
      p('APPENDED', { bold: true }),
      bullet('Selected photographs'),
      ph('appended_items'),

      // ── DISCLAIMER ────────────────────────────────────────────────────
      spacer(160),
      rule(),
      new Paragraph({
        spacing: { before: 80, after: 0 },
        children: [new TextRun({
          text: 'This report (including any enclosures and attachments) has been prepared for the exclusive use and benefit of the addressee(s) and solely for the purpose for which it is provided. Save to the extent provided for in the Company\u2019s Terms and Conditions or such other contract between the Company (or its affiliate) and the Client (or its affiliate) governing the issuance of this report, the Company assumes no liability to the addressee(s) for any claims, loss or damage whatsoever suffered by the addressee(s) as a result of any act, omission or default on the part of the Company or any of its servants, whether due to negligence or otherwise. No part of this report shall be reproduced, distributed or communicated to any third party without the prior written consent of the Company. The Company does not assume any liability or owe any duty of care if this report is used for a purpose other than that for which it is intended or where it is disclosed to or used by a third party.',
          size: 16, font: 'Calibri', color: '666666', italics: true,
        })]
      }),

      // ── SELECTED PHOTOGRAPHS (page 2) ─────────────────────────────────
      new Paragraph({
        children: [new PageBreak()]
      }),
      heading('SELECTED PHOTOGRAPHS'),
      ph('photos_grid'),
    ]
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync('/home/claude/templates_build/template_abl.docx', buf);
  console.log('✓ template_abl.docx written (' + buf.length + ' bytes)');
});
