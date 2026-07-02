// lib/shared/widgets/chip_row.dart
//
// Generic single-select chip row for small fixed-option enums. Extracted
// from vessel_compliance_screen.dart so other screens (e.g. the vessel
// particulars Regulatory Standard / AMSA Class selectors) don't each grow
// their own private copy.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: values.map((v) {
        final active = v == selected;
        return ChoiceChip(
          label: Text(label(v),
              style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : AppColors.textSecondary)),
          selected: active,
          selectedColor: AppColors.midBlue,
          backgroundColor: AppColors.surface,
          side: BorderSide(
              color: active ? AppColors.midBlue : AppColors.border),
          onSelected: (_) => onChanged(active ? null : v),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
