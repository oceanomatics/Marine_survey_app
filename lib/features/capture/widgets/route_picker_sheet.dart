// lib/features/capture/widgets/route_picker_sheet.dart

import 'package:flutter/material.dart';
import '../providers/quick_capture_provider.dart';
import '../../../shared/theme/app_theme.dart';

class RoutePickerSheet extends StatelessWidget {
  const RoutePickerSheet({
    super.key,
    required this.item,
    required this.onRoute,
  });

  final QuickCaptureModel item;
  final ValueChanged<RoutedTo> onRoute;

  static const _destinations = [
    (RoutedTo.damageItem,        AppColors.coral,   AppColors.lightCoral,   Icons.warning_amber_outlined),
    (RoutedTo.checklist,         AppColors.green,   AppColors.lightGreen,   Icons.checklist_outlined),
    (RoutedTo.docRequest,        AppColors.amber,   AppColors.lightAmber,   Icons.description_outlined),
    (RoutedTo.interviewQuestion, AppColors.purple,  AppColors.lightPurple,  Icons.mic_outlined),
    (RoutedTo.occurrenceNote,    AppColors.midBlue, AppColors.lightBlue,    Icons.event_note_outlined),
    (RoutedTo.generalNote,       AppColors.teal,    AppColors.lightTeal,    Icons.sticky_note_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Route to...',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),

          // Preview the capture content
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              item.content,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),

          // Destination grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: _destinations.map((d) {
              final (dest, color, bgColor, icon) = d;
              return _DestButton(
                destination: dest,
                color: color,
                bgColor: bgColor,
                icon: icon,
                onTap: () => onRoute(dest),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DestButton extends StatelessWidget {
  const _DestButton({
    required this.destination,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.onTap,
  });

  final RoutedTo destination;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                destination.label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
