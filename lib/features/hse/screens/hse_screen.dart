import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';

class HseScreen extends StatelessWidget {
  const HseScreen({super.key, required this.caseId});
  final String caseId;

  static const _kAccent = Color(0xFFD4500A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/cases/$caseId'),
        ),
        title: const Text(
          'HSE',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _kAccent),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.health_and_safety_outlined,
                    size: 48, color: _kAccent.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 20),
              const Text(
                'HSE — Coming Soon',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'JSEA, Permit to Work, toolbox talks\nand other HSE records will live here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
