// lib/features/interviews/widgets/interview_recording_overlay.dart
//
// Global floating indicator (14 July 2026 walkthrough — "recording should
// keep running as something like a persistent overlay/floating indicator
// across screens"). Rendered app-wide (see main.dart) so the surveyor can
// see and control an in-progress interview recording from any screen, not
// just the Interview screen itself.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/interview_recording_provider.dart';
import '../../../core/config/app_router.dart';
import '../../../shared/theme/app_theme.dart';

class InterviewRecordingOverlay extends ConsumerWidget {
  const InterviewRecordingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(interviewRecordingProvider);
    if (!rec.isRecording || rec.caseId == null) return const SizedBox.shrink();

    final minutes = (rec.seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (rec.seconds % 60).toString().padLeft(2, '0');

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => appRouter.go('/cases/${rec.caseId}/interview'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Recording interview  $minutes:$seconds',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => appRouter.go('/cases/${rec.caseId}/interview'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Open',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
