// lib/features/reports/screens/report_builder_screen.dart — stub, will be built out in subsequent sessions
import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class ReportBuilderScreen extends StatelessWidget {
  const ReportBuilderScreen({super.key, required this.caseId, this.reportSection, this.stage});
  final String caseId;
  final String? reportSection;
  final String? stage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ReportBuilderScreen')),
      body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.construction_outlined, size: 48, color: AppColors.textTertiary),
        SizedBox(height: 12),
        Text('Coming next session',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ])),
    );
  }
}
