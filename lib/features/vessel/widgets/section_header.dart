// lib/features/vessel/widgets/section_header.dart

import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class VesselSectionHeader extends StatelessWidget {
  const VesselSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
