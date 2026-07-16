// lib/features/vessel/widgets/machinery_equipment_section.dart
//
// Reusable Machinery & Equipment list + add/edit/delete, driven by the shared
// machineryProvider(vesselId). Extracted so it can appear not only on the
// Vessel → Machinery tab but also — for convenience — in Additional
// Information → Previous Work, where the surveyor documents prior works on the
// damaged item. Reported 16 July 2026: entering machinery meant digging three
// menus deep (Case → Vessel → Machinery → Edit) with no clear entry point when
// you reach that part of the questionnaire; this surfaces the same list (same
// data, edits sync both ways) right where it's needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vessel_provider.dart';
import 'add_machinery_sheet.dart';
import 'machinery_card.dart';
import 'section_header.dart';
import '../../../shared/theme/app_theme.dart';

class MachineryEquipmentSection extends ConsumerWidget {
  const MachineryEquipmentSection({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vesselAsync = ref.watch(vesselForCaseProvider(caseId));
    return vesselAsync.when(
      loading: () => const _Busy(),
      error: (e, _) => _Hint('Could not load vessel: $e'),
      data: (vessel) {
        if (vessel == null) {
          return const _Hint(
              'Save the vessel particulars first to record machinery here.');
        }
        final vesselId = vessel.vesselId;
        final machineryAsync = ref.watch(machineryProvider(vesselId));
        return machineryAsync.when(
          loading: () => const _Busy(),
          error: (e, _) => _Hint('Could not load machinery: $e'),
          data: (machinery) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VesselSectionHeader(
                title: 'Machinery & Equipment',
                icon: Icons.settings_outlined,
                color: AppColors.teal,
              ),
              const SizedBox(height: 4),
              const Text(
                'Same list as Vessel → Machinery — shown here so you can '
                'capture units while documenting previous work.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 14),
              if (machinery.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No machinery recorded yet.\n'
                    'Add main engines, generators, thrusters…',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  ),
                )
              else
                for (final m in machinery) ...[
                  MachineryCard(
                    key: ValueKey(m.machineryId),
                    machinery: m,
                    caseId: caseId,
                    onEdit: () => _showAddEdit(context, ref,
                        vesselId: vesselId, existing: m),
                    onDelete: () => _confirmDelete(context, ref, m),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showAddEdit(context, ref, vesselId: vesselId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Machinery / Equipment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddEdit(BuildContext context, WidgetRef ref,
      {required String vesselId, MachineryModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMachinerySheet(
        vesselId: vesselId,
        caseId: caseId,
        existing: existing,
        onSave: (m) async {
          if (existing != null) {
            await ref
                .read(machineryProvider(vesselId).notifier)
                .updateMachinery(m);
            return m;
          }
          return ref
              .read(machineryProvider(vesselId).notifier)
              .addMachinery(m);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, MachineryModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete machinery?'),
        content: Text('Remove ${m.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(machineryProvider(m.vesselId).notifier)
          .deleteMachinery(m.machineryId);
    }
  }
}

class _Busy extends StatelessWidget {
  const _Busy();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic)),
      );
}
