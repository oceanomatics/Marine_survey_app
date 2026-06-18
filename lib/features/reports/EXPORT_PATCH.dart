// PATCH for lib/features/reports/screens/report_builder_screen.dart
//
// Add these two imports at the top:
//
// import '../widgets/export_button.dart';
//
// Then in _ReportBuilderScreenState.build(), find the TabBarView preview tab:
//
//   ReportPreview(
//     output: _activeOutput!,
//     assembled: assembled,
//     sections: sections,
//   ),
//
// Wrap it with a Column that adds the export button at the bottom:
//
//   Column(
//     children: [
//       Expanded(
//         child: ReportPreview(
//           output: _activeOutput!,
//           assembled: assembled,
//           sections: sections,
//         ),
//       ),
//       Container(
//         padding: const EdgeInsets.all(16),
//         color: Colors.white,
//         child: ExportButton(
//           output:    _activeOutput!,
//           assembled: assembled,
//           sections:  sections,
//         ),
//       ),
//     ],
//   ),
//
// Also add the export button to the AppBar actions alongside _StatusActions:
//
//   actions: [
//     if (_activeOutput != null && assembled != null)
//       Padding(
//         padding: const EdgeInsets.only(right: 8),
//         child: ExportButton(
//           output:    _activeOutput!,
//           assembled: assembled,   // pass from data callback
//           sections:  sections,
//         ),
//       ),
//     if (_activeOutput != null && sections.isNotEmpty)
//       _StatusActions(...),
//   ],
