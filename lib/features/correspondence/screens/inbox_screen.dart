// lib/features/correspondence/screens/inbox_screen.dart — stub, will be built out in subsequent sessions
import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InboxScreen')),
      body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.construction_outlined, size: 48, color: AppColors.textTertiary),
        SizedBox(height: 12),
        Text('Coming next session',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ])),
    );
  }
}
