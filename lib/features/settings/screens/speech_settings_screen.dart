// lib/features/settings/screens/speech_settings_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/model_manager.dart';
import '../providers/speech_settings_provider.dart';
import '../../../shared/theme/app_theme.dart';

class SpeechSettingsScreen extends ConsumerStatefulWidget {
  const SpeechSettingsScreen({super.key});

  @override
  ConsumerState<SpeechSettingsScreen> createState() =>
      _SpeechSettingsScreenState();
}

class _SpeechSettingsScreenState extends ConsumerState<SpeechSettingsScreen> {
  // Per-model download state
  final Map<String, _DlState> _dlState = {};

  @override
  void initState() {
    super.initState();
    for (final m in SherpaModelConfig.catalog) {
      _dlState[m.id] = _DlState();
    }
    _refreshDisk();
  }

  Future<void> _refreshDisk() async {
    for (final m in SherpaModelConfig.catalog) {
      final bytes = await ModelManager.instance.diskBytes(m.id);
      final ready = await ModelManager.instance.isReady(m.id);
      if (mounted) {
        setState(() {
          _dlState[m.id]!
            ..diskBytes = bytes
            ..ready     = ready;
        });
      }
    }
  }

  Future<void> _download(String modelId) async {
    setState(() => _dlState[modelId]!.downloading = true);
    try {
      await for (final p in ModelManager.instance.download(modelId)) {
        if (!mounted) break;
        setState(() => _dlState[modelId]!.progress = p.totalFraction);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e'),
                     backgroundColor: AppColors.error));
      }
    }
    if (mounted) {
      setState(() => _dlState[modelId]!.downloading = false);
      await _refreshDisk();
    }
  }

  Future<void> _delete(String modelId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete model?'),
        content: const Text(
            'The model files will be removed from device storage. '
            'You can re-download at any time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await ModelManager.instance.deleteModel(modelId);
    await _refreshDisk();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(speechSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Speech & Transcription')),
      body: settingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Speech Model ───────────────────────────────────────────
            const _SectionHeader(
              icon:  Icons.memory_outlined,
              color: AppColors.navy,
              title: 'Speech Model',
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'The active model is downloaded once and used offline. '
                'Larger models are more accurate but take more storage.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            ...SherpaModelConfig.catalog.map((m) => _ModelCard(
                  config:     m,
                  isSelected: settings.modelId == m.id,
                  dlState:    _dlState[m.id]!,
                  onSelect:   () async {
                    await ref
                        .read(speechSettingsProvider.notifier)
                        .setModelId(m.id);
                    if (!(_dlState[m.id]?.ready ?? false)) {
                      _download(m.id);
                    }
                  },
                  onDownload: () => _download(m.id),
                  onDelete:   () => _delete(m.id),
                )),

            const SizedBox(height: 28),

            // ── Decoding Method ────────────────────────────────────────
            const _SectionHeader(
              icon:  Icons.tune_outlined,
              color: AppColors.teal,
              title: 'Decoding Method',
            ),
            const SizedBox(height: 10),
            _SettingsCard(children: [
              _DecodingRow(
                label:       'Beam Search',
                subtitle:    'Rescores multiple hypotheses — best accuracy',
                value:       'modified_beam_search',
                groupValue:  settings.decodingMethod,
                onChanged:   (v) => ref
                    .read(speechSettingsProvider.notifier)
                    .setDecodingMethod(v),
              ),
              const Divider(height: 1, indent: 16),
              _DecodingRow(
                label:       'Greedy',
                subtitle:    'Fastest, slightly lower accuracy',
                value:       'greedy_search',
                groupValue:  settings.decodingMethod,
                onChanged:   (v) => ref
                    .read(speechSettingsProvider.notifier)
                    .setDecodingMethod(v),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Endpoint Sensitivity ───────────────────────────────────
            const _SectionHeader(
              icon:  Icons.graphic_eq_outlined,
              color: AppColors.purple,
              title: 'Endpoint Sensitivity',
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Controls how long a pause triggers a sentence break.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            _SettingsCard(children: [
              for (int i = 0; i < EndpointSensitivity.values.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                _EndpointRow(
                  value:      EndpointSensitivity.values[i],
                  groupValue: settings.endpointSensitivity,
                  onChanged:  (v) => ref
                      .read(speechSettingsProvider.notifier)
                      .setEndpointSensitivity(v),
                ),
              ],
            ]),

            const SizedBox(height: 28),

            // ── Storage Summary ────────────────────────────────────────
            const _SectionHeader(
              icon:  Icons.sd_storage_outlined,
              color: AppColors.amber,
              title: 'Storage',
            ),
            const SizedBox(height: 10),
            _StorageSummary(dlStates: _dlState),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Model card ─────────────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.config,
    required this.isSelected,
    required this.dlState,
    required this.onSelect,
    required this.onDownload,
    required this.onDelete,
  });

  final SherpaModelConfig config;
  final bool              isSelected;
  final _DlState          dlState;
  final VoidCallback      onSelect;
  final VoidCallback      onDownload;
  final VoidCallback      onDelete;

  @override
  Widget build(BuildContext context) {
    final qualityColor = config.quality == 'Accurate'
        ? AppColors.teal
        : AppColors.midBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:  isSelected ? AppColors.navy : AppColors.border,
          width:  isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(children: [
                  // Radio
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.navy : AppColors.border,
                        width: isSelected ? 6 : 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(config.displayName,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.navy
                                    : AppColors.textPrimary)),
                        Text(config.description,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quality badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(config.quality,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: qualityColor)),
                  ),
                ]),

                const SizedBox(height: 12),

                // Storage bar + actions row
                Row(children: [
                  Expanded(
                      child: _StorageBar(config: config, dlState: dlState)),
                  const SizedBox(width: 12),
                  _ModelAction(
                    ready:       dlState.ready,
                    downloading: dlState.downloading,
                    onDownload:  onDownload,
                    onDelete:    onDelete,
                  ),
                ]),

                // Download progress bar
                if (dlState.downloading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value:           dlState.progress,
                      minHeight:       4,
                      backgroundColor: AppColors.lightBlue,
                      color:           AppColors.midBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(dlState.progress * 100).toStringAsFixed(0)}%  '
                    '— ~${config.estimatedMb} MB total',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Storage bar ────────────────────────────────────────────────────────────

class _StorageBar extends StatelessWidget {
  const _StorageBar({required this.config, required this.dlState});
  final SherpaModelConfig config;
  final _DlState          dlState;

  @override
  Widget build(BuildContext context) {
    final totalBytes = config.estimatedMb * 1024 * 1024;
    final fraction   = dlState.diskBytes > 0
        ? (dlState.diskBytes / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final usedMb     = (dlState.diskBytes / (1024 * 1024));
    final label      = dlState.ready
        ? '${usedMb.toStringAsFixed(1)} MB on device'
        : dlState.diskBytes > 0
            ? '${usedMb.toStringAsFixed(1)} / ${config.estimatedMb} MB'
            : 'Not downloaded  ·  ~${config.estimatedMb} MB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value:           fraction,
            minHeight:       5,
            backgroundColor: AppColors.border,
            color:           dlState.ready
                ? AppColors.teal
                : AppColors.midBlue,
          ),
        ),
      ],
    );
  }
}

// ── Model action button ────────────────────────────────────────────────────

class _ModelAction extends StatelessWidget {
  const _ModelAction({
    required this.ready,
    required this.downloading,
    required this.onDownload,
    required this.onDelete,
  });
  final bool         ready, downloading;
  final VoidCallback onDownload, onDelete;

  @override
  Widget build(BuildContext context) {
    if (downloading) {
      return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.midBlue));
    }
    if (ready) {
      return GestureDetector(
        onTap: onDelete,
        child: const Icon(Icons.delete_outline,
            size: 20, color: AppColors.textTertiary),
      );
    }
    return GestureDetector(
      onTap: onDownload,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        AppColors.navy,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_outlined, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text('Download',
              style: TextStyle(fontSize: 11,
                  color: Colors.white, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Decoding row ────────────────────────────────────────────────────────────

class _DecodingRow extends StatelessWidget {
  const _DecodingRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String   label, subtitle, value, groupValue;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: _RadioDot(
          selected: value == groupValue,
          color:    AppColors.teal,
        ),
        onTap: () => onChanged(value),
        dense: true,
      );
}

// ── Endpoint row ────────────────────────────────────────────────────────────

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final EndpointSensitivity value, groupValue;
  final void Function(EndpointSensitivity) onChanged;

  @override
  Widget build(BuildContext context) {
    final (r1, r2) = value.thresholds;
    return ListTile(
      title: Text(value.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text('${value.hint}  ·  ${r1}s / ${r2}s',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      trailing: _RadioDot(
        selected: value == groupValue,
        color:    AppColors.purple,
      ),
      onTap: () => onChanged(value),
      dense: true,
    );
  }
}

// ── Storage summary ─────────────────────────────────────────────────────────

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.dlStates});
  final Map<String, _DlState> dlStates;

  @override
  Widget build(BuildContext context) {
    final totalBytes = dlStates.values
        .fold<int>(0, (sum, s) => sum + s.diskBytes);
    final totalMb = totalBytes / (1024 * 1024);
    final downloaded = dlStates.values.where((s) => s.ready).length;

    return _SettingsCard(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          const Icon(Icons.folder_outlined,
              size: 32, color: AppColors.amber),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalBytes == 0
                      ? 'No models on device'
                      : '${totalMb.toStringAsFixed(1)} MB used by $downloaded model${downloaded == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Models are stored in app documents folder',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ]),
      ),
      // Per-model breakdown
      ...SherpaModelConfig.catalog.map((m) {
        final s      = dlStates[m.id]!;
        final usedMb = (s.diskBytes / (1024 * 1024));
        return Column(children: [
          const Divider(height: 1, indent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Text(m.displayName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
              Text(
                s.ready
                    ? '${usedMb.toStringAsFixed(1)} MB'
                    : '—',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: s.ready
                        ? AppColors.textPrimary
                        : AppColors.textTertiary),
              ),
            ]),
          ),
        ]);
      }),
    ]);
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.color});
  final bool  selected;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 20, height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 6 : 2,
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });
  final IconData icon;
  final Color    color;
  final String   title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8),
        ),
      ]);
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );
}

// ── Mutable download state ─────────────────────────────────────────────────

class _DlState {
  bool   ready       = false;
  bool   downloading = false;
  double progress    = 0;
  int    diskBytes   = 0;
}
