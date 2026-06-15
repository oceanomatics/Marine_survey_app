// lib/features/vessel/widgets/machinery_card.dart

import 'package:flutter/material.dart';
import '../providers/vessel_provider.dart';
import '../../../shared/theme/app_theme.dart';

class MachineryCard extends StatelessWidget {
  const MachineryCard({
    super.key,
    required this.machinery,
    required this.onEdit,
    required this.onDelete,
  });

  final MachineryModel machinery;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Role badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleColor(machinery.role).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    machinery.roleLabel,
                    style: TextStyle(
                      color: _roleColor(machinery.role),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (machinery.unitNumber != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    'No. ${machinery.unitNumber}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              machinery.displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (machinery.mcrKw != null)
                  _Spec('MCR', '${machinery.mcrKw!.toStringAsFixed(0)} kW'),
                if (machinery.mcrRpm != null)
                  _Spec('RPM', machinery.mcrRpm!.toStringAsFixed(0)),
                if (machinery.fuelType != null)
                  _Spec('Fuel', machinery.fuelType!),
                if (machinery.cylinderCount != null)
                  _Spec('Cylinders', machinery.cylinderCount.toString()),
                if (machinery.serialNumber != null)
                  _Spec('S/N', machinery.serialNumber!),
                if (machinery.runHrsNew != null)
                  _Spec('Hrs (new)',
                      machinery.runHrsNew!.toStringAsFixed(0)),
                if (machinery.runHrsOverhaul != null)
                  _Spec('Hrs (O/H)',
                      machinery.runHrsOverhaul!.toStringAsFixed(0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String? role) => switch (role) {
    'main_engine'      => AppColors.navy,
    'diesel_generator' => AppColors.teal,
    'thruster'         => AppColors.midBlue,
    'turbocharger'     => AppColors.coral,
    _                  => AppColors.textSecondary,
  };
}

class _Spec extends StatelessWidget {
  const _Spec(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textTertiary)),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
