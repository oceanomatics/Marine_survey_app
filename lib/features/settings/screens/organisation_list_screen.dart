// lib/features/settings/screens/organisation_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/organisation_model.dart';
import '../providers/organisations_provider.dart';
import '../../../shared/theme/app_theme.dart';

class OrganisationListScreen extends ConsumerWidget {
  const OrganisationListScreen({super.key});

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Organisation'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Firm name',
            hintText: 'e.g. Oceanoservices Pty Ltd',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    final org = await ref
        .read(organisationsProvider.notifier)
        .createOrganisation(name: name);
    if (context.mounted) {
      context.push('/organisations/${org.organisationId}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organisationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Organisations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Organisation'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(organisationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (orgs) => orgs.isEmpty
            ? _EmptyState(onAdd: () => _createNew(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: orgs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _OrgTile(org: orgs[i]),
              ),
      ),
    );
  }
}

class _OrgTile extends StatelessWidget {
  const _OrgTile({required this.org});
  final OrganisationModel org;

  @override
  Widget build(BuildContext context) {
    final profileCount = org.surveyorProfiles.length;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _parseColour(org.primaryColour) ?? AppColors.navy,
          child: Text(
            org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(org.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (org.abn != null) 'ABN ${org.abn}',
            '$profileCount surveyor${profileCount == 1 ? '' : 's'}',
          ].join(' · '),
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/organisations/${org.organisationId}'),
      ),
    );
  }

  Color? _parseColour(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : null;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No organisations yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Create your firm profile to enable cover page branding, '
              'legal text blocks, and surveyor sign-off.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create Organisation'),
            ),
          ],
        ),
      ),
    );
  }
}
