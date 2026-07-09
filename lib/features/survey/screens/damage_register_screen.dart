// lib/features/survey/screens/damage_register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/damage_provider.dart';
import '../widgets/damage_item_card.dart';
import 'damage_item_editor_screen.dart';
import '../widgets/add_occurrence_sheet.dart';
import '../../photos/providers/photo_provider.dart';
import '../../photos/models/photo_model.dart';
import '../../vessel/providers/vessel_provider.dart';
import '../../surveyor_notes/models/surveyor_note_model.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/case_photo_picker_sheet.dart';
import '../../../shared/widgets/context_cues_panel.dart';
import '../../../shared/widgets/back_app_bar.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class DamageRegisterScreen extends ConsumerWidget {
  const DamageRegisterScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageProvider(caseId));
    final allPhotos   = ref.watch(photosProvider(caseId)).value ?? [];
    final vesselId    = ref.watch(vesselForCaseProvider(caseId)).value?.vesselId;
    final machinery   = vesselId != null
        ? ref.watch(machineryProvider(vesselId)).value ?? const <MachineryModel>[]
        : const <MachineryModel>[];

    void showAddOccurrence() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddOccurrenceSheet(
          onSave: (title, dateTime, location, description,
              vesselStatusAtCasualty, aftermathStatus, aftermathPort) async {
            await ref.read(damageProvider(caseId).notifier).createOccurrence(
                  caseId: caseId,
                  title: title,
                  dateTime: dateTime,
                  location: location,
                  briefDescription: description,
                  vesselStatusAtCasualty: vesselStatusAtCasualty,
                  aftermathStatus: aftermathStatus,
                  aftermathPort: aftermathPort,
                );
          },
        ),
      );
    }

    void showAddDamageItem(String occurrenceId, {SurveyorNote? sourceCue}) {
      final occs = damageAsync.value?.occurrences ?? [];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DamageItemEditorScreen(
            caseId: caseId,
            vesselId: vesselId,
            occurrenceId: occurrenceId,
            occurrences: occs,
            sourceCue: sourceCue,
            onSave: (item) =>
                ref.read(damageProvider(caseId).notifier).addDamageItem(item),
          ),
        ),
      );
    }

    void showEditDamageItem(DamageItemModel item, {SurveyorNote? sourceCue}) {
      final occs = damageAsync.value?.occurrences ?? [];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DamageItemEditorScreen(
            caseId: caseId,
            vesselId: vesselId,
            occurrenceId: item.occurrenceId,
            occurrences: occs,
            existing: item,
            sourceCue: sourceCue,
            onSave: (updated) async {
              await ref
                  .read(damageProvider(caseId).notifier)
                  .updateDamageItem(updated);
              return updated;
            },
          ),
        ),
      );
    }

    Future<void> addPhotoForDamageItem(String damageId) async {
      final picked = await showModalBottomSheet<List<dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => CasePhotoPickerSheet(
          caseId: caseId,
          multiSelect: true,
          title: 'Add Damage Photos',
          accentColor: AppColors.coral,
        ),
      );
      if (picked == null || picked.isEmpty || !context.mounted) return;
      for (final photo in picked) {
        await ref
            .read(photosProvider(caseId).notifier)
            .attachToDamageItem(photo.id as String, damageId);
      }
    }

    void confirmDeleteOccurrence(OccurrenceModel occ) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete occurrence?'),
          content: Text(
            'Delete "${occ.title ?? 'Occurrence ${occ.occurrenceNo}'}"? '
            'All linked damage items and repairs will also be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(damageProvider(caseId).notifier)
                    .deleteOccurrence(occ.occurrenceId);
              },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    // Row 17: cue -> damage item promotion (create new, or merge into an
    // existing item as supporting evidence) — the standing cue-action
    // principle, docs/context_cue_system_review.md.
    void promoteCue(SurveyorNote note) {
      final ds = damageAsync.value;
      if (ds == null || ds.occurrences.isEmpty) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Promote Context Cue',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('"${note.content}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.add_box_outlined,
                    color: AppColors.coral),
                title: const Text('Create new damage item'),
                subtitle: const Text('Prefills the description from this cue',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showAddDamageItem(ds.occurrences.first.occurrenceId,
                      sourceCue: note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.merge_type_outlined,
                    color: AppColors.coral),
                title: const Text('Merge into existing item'),
                subtitle: const Text(
                    'Appends this cue as supporting evidence',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickExistingDamageItem(context, ds).then((picked) {
                    if (picked != null) {
                      showEditDamageItem(picked, sourceCue: note);
                    }
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: const Text('Damage Register'),
      ),
      floatingActionButton: damageAsync.when(
        data: (ds) => FloatingActionButton.extended(
          onPressed: () => ds.occurrences.isEmpty
              ? showAddOccurrence()
              : showAddDamageItem(ds.occurrences.first.occurrenceId),
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(
            ds.occurrences.isEmpty ? 'Add Occurrence' : 'Add Damage Item',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
      body: damageAsync.when(
        loading: () =>
            const AppLoadingWidget(message: 'Loading damage register...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ds) => Column(
          children: [
            Expanded(
              child: ds.occurrences.isEmpty
                  ? _EmptyState(onAdd: showAddOccurrence)
                  : _DamageBody(
                      caseId: caseId,
                      ds: ds,
                      allPhotos: allPhotos,
                      machinery: machinery,
                      onAddItem: showAddDamageItem,
                      onEditItem: showEditDamageItem,
                      onDeleteItem: (damageId) => ref
                          .read(damageProvider(caseId).notifier)
                          .deleteDamageItem(damageId),
                      onDeleteOccurrence: confirmDeleteOccurrence,
                      onAddOccurrence: showAddOccurrence,
                      onAddPhoto: addPhotoForDamageItem,
                      onDeletePhoto: (photoId) => ref
                          .read(photosProvider(caseId).notifier)
                          .deletePhoto(photoId),
                    ),
            ),
            ContextCuesPanel(
              caseId: caseId,
              section: CaseSection.damage,
              onPromote: promoteCue,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet listing every damage item across all occurrences, for
  /// the "merge cue into existing item" promotion path.
  Future<DamageItemModel?> _pickExistingDamageItem(
      BuildContext context, DamageState ds) {
    return showModalBottomSheet<DamageItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.6),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Damage Item',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (ds.damageItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No damage items yet — create one instead.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ds.damageItems.length,
                  itemBuilder: (_, i) {
                    final item = ds.damageItems[i];
                    return ListTile(
                      title: Text(item.componentName),
                      subtitle: item.damageDescription != null
                          ? Text(item.damageDescription!,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () => Navigator.pop(sheetCtx, item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Damage body ────────────────────────────────────────────────────────────

class _DamageBody extends StatelessWidget {
  const _DamageBody({
    required this.caseId,
    required this.ds,
    required this.allPhotos,
    required this.machinery,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onDeleteOccurrence,
    required this.onAddOccurrence,
    required this.onAddPhoto,
    required this.onDeletePhoto,
  });

  final String caseId;
  final DamageState ds;
  final List<PhotoModel> allPhotos;
  final List<MachineryModel> machinery;
  final ValueChanged<String> onAddItem;
  final ValueChanged<DamageItemModel> onEditItem;
  final ValueChanged<String> onDeleteItem;
  final ValueChanged<OccurrenceModel> onDeleteOccurrence;
  final VoidCallback onAddOccurrence;
  final Future<void> Function(String damageId) onAddPhoto;
  final void Function(String photoId) onDeletePhoto;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        for (final occ in (List.of(ds.occurrences)
              ..sort((a, b) => a.occurrenceNo.compareTo(b.occurrenceNo)))) ...[
          SliverToBoxAdapter(
            child: _OccurrenceHeader(
              occurrence: occ,
              itemCount: ds.itemsForOccurrence(occ.occurrenceId).length,
              onAddItem: () => onAddItem(occ.occurrenceId),
              onDelete: () => onDeleteOccurrence(occ),
            ),
          ),

          for (final group in _groupByClaimObject(
              ds.itemsForOccurrence(occ.occurrenceId))) ...[
            SliverToBoxAdapter(
              child: _ClaimObjectSubHeader(
                label: group.label,
                count: group.items.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final item = group.items[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: DamageItemCard(
                      item: item,
                      onEdit: () => onEditItem(item),
                      onDelete: () => _confirmDelete(ctx, item.damageId),
                      photos: allPhotos.forDamageItem(item.damageId),
                      onAddPhoto: () => onAddPhoto(item.damageId),
                      onDeletePhoto: onDeletePhoto,
                    ),
                  );
                },
                childCount: group.items.length,
              ),
            ),
          ],

          if (ds.itemsForOccurrence(occ.occurrenceId).isEmpty)
            SliverToBoxAdapter(
              child: _EmptyOccurrence(
                  onAdd: () => onAddItem(occ.occurrenceId)),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
            child: OutlinedButton.icon(
              onPressed: onAddOccurrence,
              icon: const Icon(Icons.add),
              label: const Text('Add Another Occurrence'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: const BorderSide(color: AppColors.coral),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Groups damage items by claim object (spec §7: claim-object-first, not
  /// category-first) — machinery record when linked, otherwise the item's
  /// own component name stands in as its claim object. Preserves the
  /// items' existing sequence order both within and across groups.
  List<_ClaimObjectGroup> _groupByClaimObject(List<DamageItemModel> items) {
    final groups = <String, _ClaimObjectGroup>{};
    for (final item in items) {
      final key = item.machineryId ?? 'unlinked:${item.componentName}';
      final existing = groups[key];
      if (existing != null) {
        existing.items.add(item);
        continue;
      }
      final label = item.machineryId != null
          ? machinery
              .where((m) => m.machineryId == item.machineryId)
              .map((m) => '${m.roleLabel}: ${m.displayName}')
              .firstOrNull ??
              item.componentName
          : item.componentName;
      groups[key] = _ClaimObjectGroup(label: label, items: [item]);
    }
    return groups.values.toList();
  }

  void _confirmDelete(BuildContext context, String damageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete damage item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDeleteItem(damageId);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Summary banner ─────────────────────────────────────────────────────────

// ── Occurrence header ──────────────────────────────────────────────────────

class _OccurrenceHeader extends StatelessWidget {
  const _OccurrenceHeader({
    required this.occurrence,
    required this.itemCount,
    required this.onAddItem,
    required this.onDelete,
  });

  final OccurrenceModel occurrence;
  final int itemCount;
  final VoidCallback onAddItem;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightCoral,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                occurrence.occurrenceNo.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.title ??
                      'Occurrence ${occurrence.occurrenceNo}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral),
                ),
                if (occurrence.dateTime != null)
                  Text(
                    _fmtDate(occurrence.dateTime!),
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.coral.withValues(alpha: 0.7)),
                  ),
                if (occurrence.location != null &&
                    occurrence.location!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.coral.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        occurrence.location!,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.coral.withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.coral.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onAddItem,
                    child: const Icon(Icons.add_circle_outline,
                        color: AppColors.coral, size: 22),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: AppColors.coral.withValues(alpha: 0.8), size: 20),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete occurrence',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Claim object grouping ───────────────────────────────────────────────────

class _ClaimObjectGroup {
  _ClaimObjectGroup({required this.label, required this.items});
  final String label;
  final List<DamageItemModel> items;
}

// ── Claim object sub-header ────────────────────────────────────────────────

class _ClaimObjectSubHeader extends StatelessWidget {
  const _ClaimObjectSubHeader({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.coral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 3),
      child: Row(children: [
        const Icon(Icons.precision_manufacturing_outlined,
            size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '($count)',
          style: TextStyle(
              fontSize: 10, color: color.withValues(alpha: 0.6)),
        ),
      ]),
    );
  }
}

// ── Empty states ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No occurrences recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text(
            'Add an occurrence to start recording\ndamage items',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Occurrence'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}

class _EmptyOccurrence extends StatelessWidget {
  const _EmptyOccurrence({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add first damage item',
            style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
