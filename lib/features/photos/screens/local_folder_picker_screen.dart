// lib/features/photos/screens/local_folder_picker_screen.dart
//
// Shows all images found in a local directory.
// Opens with everything selected; user can deselect individual files or
// use "Deselect All". Pops with List<File> for the caller to read.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/back_app_bar.dart';

class LocalFolderPickerScreen extends StatefulWidget {
  const LocalFolderPickerScreen({
    super.key,
    required this.files,
    required this.dirPath,
  });

  final List<File> files;
  final String dirPath;

  @override
  State<LocalFolderPickerScreen> createState() =>
      _LocalFolderPickerScreenState();
}

class _LocalFolderPickerScreenState extends State<LocalFolderPickerScreen> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // Start with everything selected.
    _selected = widget.files.map((f) => f.path).toSet();
  }

  bool get _allSelected => _selected.length == widget.files.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(widget.files.map((f) => f.path));
      }
    });
  }

  void _toggle(File f) {
    setState(() {
      if (_selected.contains(f.path)) {
        _selected.remove(f.path);
      } else {
        _selected.add(f.path);
      }
    });
  }

  void _confirm() {
    final result = widget.files
        .where((f) => _selected.contains(f.path))
        .toList();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Images', style: TextStyle(fontSize: 15)),
            Text(
              p.basename(widget.dirPath),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _toggleAll,
            child: Text(
              _allSelected ? 'Deselect All' : 'Select All',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: widget.files.isEmpty
          ? const Center(
              child: Text('No images found in this folder.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.files.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 66, endIndent: 16),
              itemBuilder: (_, i) {
                final file = widget.files[i];
                final selected = _selected.contains(file.path);
                final stat = file.statSync();

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      file,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48, height: 48,
                        color: AppColors.surface,
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  title: Text(
                    p.basename(file.path),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _fmtSize(stat.size),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                  trailing: Checkbox(
                    value: selected,
                    activeColor: AppColors.purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggle(file),
                  ),
                  onTap: () => _toggle(file),
                );
              },
            ),
      bottomNavigationBar: n == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    _allSelected
                        ? 'Import All ($n)'
                        : 'Import $n Image${n == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
