// lib/features/photos/screens/drive_folder_picker_screen.dart
//
// Google Drive folder browser.
//
// Flow:
//   1. Screen opens → silent sign-in → loads "My Drive" root.
//   2. User navigates folders; images are shown with checkboxes.
//   3. "Select All" button in AppBar toggles all images in the current folder.
//   4. "Import N Images" button downloads selected files and pops with
//      List<Uint8List> so the caller can save them via photosProvider.
//
// If the user cancels Google sign-in the screen closes silently.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/google_drive_service.dart';
import '../../../shared/theme/app_theme.dart';

class DriveFolderPickerScreen extends StatefulWidget {
  const DriveFolderPickerScreen({super.key});

  @override
  State<DriveFolderPickerScreen> createState() =>
      _DriveFolderPickerScreenState();
}

// Lightweight breadcrumb entry.
class _Crumb {
  const _Crumb(this.id, this.name);
  final String id;
  final String name;
}

class _DriveFolderPickerScreenState extends State<DriveFolderPickerScreen> {
  final List<_Crumb> _stack = [const _Crumb('root', 'My Drive')];
  List<DriveItem> _items = [];
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};

  // Download progress
  bool _downloading = false;
  int _downloadDone = 0;
  int _downloadTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _currentId => _stack.last.id;

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });

    try {
      final items = await GoogleDriveService.listFolder(_currentId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on DriveSignInCancelled {
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _enterFolder(DriveItem folder) {
    _stack.add(_Crumb(folder.id, folder.name));
    _load();
  }

  void _goBack() {
    if (_stack.length > 1) {
      _stack.removeLast();
      _load();
    } else {
      Navigator.pop(context);
    }
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  List<DriveItem> get _images => _items.where((i) => !i.isFolder).toList();

  void _toggleAll() {
    final imgs = _images;
    if (_selected.length == imgs.length && imgs.isNotEmpty) {
      setState(() => _selected.clear());
    } else {
      setState(() {
        _selected
          ..clear()
          ..addAll(imgs.map((i) => i.id));
      });
    }
  }

  void _toggleItem(DriveItem item) {
    setState(() {
      if (_selected.contains(item.id)) {
        _selected.remove(item.id);
      } else {
        _selected.add(item.id);
      }
    });
  }

  // ── Download + pop ────────────────────────────────────────────────────────

  Future<void> _import() async {
    final toDownload = _items.where((i) => _selected.contains(i.id)).toList();
    if (toDownload.isEmpty) return;

    setState(() {
      _downloading = true;
      _downloadDone = 0;
      _downloadTotal = toDownload.length;
    });

    try {
      final results = <Uint8List>[];
      for (final item in toDownload) {
        if (!mounted) return;
        final bytes = await GoogleDriveService.downloadFile(item.id);
        results.add(bytes);
        if (mounted) setState(() => _downloadDone++);
      }
      if (mounted) Navigator.pop(context, results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _images.isNotEmpty && _selected.length == _images.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _downloading ? null : _goBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Google Drive', style: TextStyle(fontSize: 15)),
            Text(
              _stack.map((e) => e.name).join('  ›  '),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (!_loading && !_downloading && _images.isNotEmpty)
            TextButton(
              onPressed: _toggleAll,
              child: Text(
                allSelected ? 'Deselect All' : 'Select All',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.coral),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No images or sub-folders here.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 58, endIndent: 16),
      itemBuilder: (_, i) {
        final item = _items[i];
        return item.isFolder ? _buildFolderTile(item) : _buildImageTile(item);
      },
    );
  }

  Widget _buildFolderTile(DriveItem folder) {
    return ListTile(
      leading:
          const Icon(Icons.folder_rounded, color: AppColors.amber, size: 30),
      title: Text(folder.name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: _downloading ? null : () => _enterFolder(folder),
    );
  }

  Widget _buildImageTile(DriveItem img) {
    final selected = _selected.contains(img.id);
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.purple.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child:
            const Icon(Icons.image_outlined, color: AppColors.purple, size: 22),
      ),
      title: Text(img.name,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis),
      subtitle: img.sizeBytes != null
          ? Text(
              _fmtSize(img.sizeBytes!),
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            )
          : null,
      trailing: Checkbox(
        value: selected,
        activeColor: AppColors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onChanged: _downloading ? null : (_) => _toggleItem(img),
      ),
      onTap: _downloading ? null : () => _toggleItem(img),
    );
  }

  Widget? _buildBottom() {
    // ── Download progress ──────────────────────────────────────────────
    if (_downloading) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    _downloadTotal > 0 ? _downloadDone / _downloadTotal : null,
                backgroundColor: AppColors.border,
                color: AppColors.purple,
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Downloading $_downloadDone / $_downloadTotal…',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // ── Import button ──────────────────────────────────────────────────
    if (_selected.isEmpty) return null;

    final n = _selected.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ElevatedButton.icon(
          onPressed: _import,
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text(
            'Import $n Image${n == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
