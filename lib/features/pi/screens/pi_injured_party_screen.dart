// lib/features/pi/screens/pi_injured_party_screen.dart
//
// P&I / Expert — Medical / Injured Parties register (spec §4.6). One entry
// per affected person: role, condition, and the source of that information.
// Activated only for casualty matters involving injury.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/back_app_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../models/pi_models.dart';
import '../providers/pi_injured_party_provider.dart';

const _kPiColor = Color(0xFF3B4A8C);

class PiInjuredPartyScreen extends ConsumerWidget {
  const PiInjuredPartyScreen({super.key, required this.caseId});
  final String caseId;

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final roleCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final condCtrl = TextEditingController();
    final srcCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add injured party'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Role (crew / passenger / third party)')),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name (optional — may be withheld)')),
              TextField(
                  controller: condCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Condition')),
              TextField(
                  controller: srcCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Source of information')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (saved == true &&
        (roleCtrl.text.trim().isNotEmpty ||
            condCtrl.text.trim().isNotEmpty)) {
      String? v(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await ref.read(piInjuredPartyProvider(caseId).notifier).add(
            personRole: v(roleCtrl),
            personName: v(nameCtrl),
            condition: v(condCtrl),
            infoSource: v(srcCtrl),
          );
      if (context.mounted) showSavedToast(context, label: 'Entry added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(piInjuredPartyProvider(caseId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: Text('Injured Parties')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        backgroundColor: _kPiColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (parties) {
          if (parties.isEmpty) {
            return const Center(
              child: Text('No injured parties recorded',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              for (final p in parties) _PartyCard(caseId: caseId, party: p)
            ],
          );
        },
      ),
    );
  }
}

class _PartyCard extends ConsumerWidget {
  const _PartyCard({required this.caseId, required this.party});
  final String caseId;
  final PiInjuredPartyModel party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = [party.personRole, party.personName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        title: Text(title.isEmpty ? '(unspecified)' : title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (party.condition != null && party.condition!.isNotEmpty)
              Text(party.condition!),
            if (party.infoSource != null && party.infoSource!.isNotEmpty)
              Text('Source: ${party.infoSource}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: AppColors.textSecondary,
          onPressed: () =>
              ref.read(piInjuredPartyProvider(caseId).notifier).delete(party.id),
        ),
      ),
    );
  }
}
