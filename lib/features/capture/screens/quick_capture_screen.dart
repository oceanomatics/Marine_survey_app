// lib/features/capture/screens/quick_capture_screen.dart — stub
import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class QuickCaptureScreen extends StatelessWidget {
  const QuickCaptureScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Capture Inbox')),
      body: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text('Coming next session',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
