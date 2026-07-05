// lib/shared/widgets/photo_picker_sheet.dart
//
// Unified photo import sheet used everywhere in the app.
// Sources: Camera, Photo Library, Files (individual), Folder (all images).
//
// Usage:
//   final source = await showModalBottomSheet<PhotoPickSource>(
//     context: context,
//     backgroundColor: Colors.transparent,
//     builder: (_) => const PhotoPickerSheet(),
//   );
//   if (source == null || !mounted) return;
//   final bytesList = await PhotoPickerSheet.resolveBytes(source, context: context);
//
// Pass context for localFolder and driveFolder.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../features/photos/screens/drive_folder_picker_screen.dart';
import '../../features/photos/screens/local_folder_picker_screen.dart';
import '../theme/app_theme.dart';

enum PhotoPickSource { camera, gallery, files, localFolder, driveFolder }

class PhotoPickerSheet extends StatelessWidget {
  const PhotoPickerSheet({
    super.key,
    this.accentColor = AppColors.purple,
    this.title = 'Add Photos',
  });

  final Color accentColor;
  final String title;

  // Image file extensions recognised for folder scanning.
  static const _imageExts = {
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
    '.tiff',
    '.tif',
    '.bmp',
  };

  /// On Android, `FilePicker.getDirectoryPath()` can return a SAF content URI
  /// like `content://com.android.externalstorage.documents/tree/primary%3ADCIM`.
  /// Convert that to the real /storage/emulated/0/... path so dart:io can walk it.
  /// Paths that are already absolute file paths are returned unchanged.
  static String _resolveAndroidUri(String raw) {
    if (!raw.startsWith('content://')) return raw;

    // Extract the tree document ID, e.g. "primary:DCIM/Camera"
    final treeIdx = raw.indexOf('/tree/');
    if (treeIdx == -1) return raw;
    final encoded = raw.substring(treeIdx + 6).split('/document/').first;
    final decoded = Uri.decodeComponent(encoded); // "primary:DCIM/Camera"
    final colon = decoded.indexOf(':');
    if (colon == -1) return raw;

    final volume = decoded.substring(0, colon).toLowerCase();
    final rest = decoded.substring(colon + 1);
    if (volume == 'primary') return '/storage/emulated/0/$rest';
    // Named SD-card volume (e.g. "1234-5678")
    return '/storage/$volume/$rest';
  }

  static void _showCloudFolderError(BuildContext context, String rawPath) {
    final isGoogleDrive = rawPath.contains('acc=') ||
        rawPath.contains('doc=encoded=') ||
        rawPath.contains('com.google');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Folder not accessible'),
        content: Text(
          isGoogleDrive
              ? 'Google Drive folders cannot be browsed directly on this device.\n\n'
                  'To import Drive photos:\n'
                  '• Use "Files / Cloud Drive" → navigate to the folder → select files individually\n'
                  '• Or open Google Drive, make the folder available offline, then try again'
              : 'This folder is provided by a cloud storage app and cannot '
                  'be read directly.\n\nUse "Files / Cloud Drive" to select '
                  'individual files instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Folder-only path: opens the directory picker and the selection screen,
  /// returning [File] handles so the caller can read + process them lazily
  /// (no up-front memory spike from buffering all bytes at once).
  /// Returns null on cancel, [] if no images found.
  static Future<List<File>?> resolveFiles({BuildContext? context}) async {
    if (context == null || !context.mounted) return null;

    final rawPath = await FilePicker.getDirectoryPath();
    debugPrint('[FolderImport] raw path from picker: $rawPath');
    if (rawPath == null || rawPath.isEmpty) return null;

    final dirPath = _resolveAndroidUri(rawPath);
    debugPrint('[FolderImport] resolved path: $dirPath');

    final isCloudPath = rawPath.contains('acc=') ||
        rawPath.contains('doc=encoded=') ||
        rawPath.contains('com.google') ||
        rawPath.contains('com.dropbox') ||
        (!rawPath.startsWith('/storage') &&
            !rawPath.startsWith('/sdcard') &&
            rawPath.startsWith('/'));
    final dirExists = !isCloudPath && Directory(dirPath).existsSync();

    if (!dirExists) {
      debugPrint(
          '[FolderImport] path is not a local directory (cloud provider?)');
      if (context.mounted) _showCloudFolderError(context, rawPath);
      return null;
    }

    List<File> imageFiles = [];
    try {
      imageFiles = Directory(dirPath)
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => _imageExts.contains(p.extension(f.path).toLowerCase()))
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      debugPrint('[FolderImport] found ${imageFiles.length} images');
    } catch (e) {
      debugPrint('[FolderImport] ERROR listing directory: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not read folder: $e'),
              duration: const Duration(seconds: 5)),
        );
      }
      return null;
    }

    if (imageFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No images found in:\n$dirPath'),
              duration: const Duration(seconds: 4)),
        );
      }
      return [];
    }

    if (!context.mounted) return null;

    final selected = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocalFolderPickerScreen(
          files: imageFiles,
          dirPath: dirPath,
        ),
      ),
    );
    return selected; // null = cancelled, [] = deselected all
  }

  /// Resolve a [PhotoPickSource] into raw image bytes.
  ///
  /// Pass [context] for [localFolder] (and future [driveFolder]) — it is used
  /// to push the selection screen. Returns [] if the user cancels.
  static Future<List<Uint8List>> resolveBytes(
    PhotoPickSource source, {
    BuildContext? context,
  }) async {
    switch (source) {
      // ── Camera ─────────────────────────────────────────────────────────────
      case PhotoPickSource.camera:
        final f = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 3000,
        );
        if (f == null) return [];
        return [await f.readAsBytes()];

      // ── Gallery (multi-select) ─────────────────────────────────────────────
      case PhotoPickSource.gallery:
        final files = await ImagePicker().pickMultiImage(imageQuality: 90);
        if (files.isEmpty) return [];
        return await Future.wait(files.map((f) => f.readAsBytes()));

      // ── Individual files via system picker ─────────────────────────────────
      case PhotoPickSource.files:
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          withData: true,
        );
        if (result == null) return [];
        return result.files
            .where((f) => f.bytes != null)
            .map((f) => Uint8List.fromList(f.bytes!))
            .toList();

      // ── Local folder — all images with checkbox selection ──────────────────
      case PhotoPickSource.localFolder:
        if (context == null || !context.mounted) return [];

        final rawPath = await FilePicker.getDirectoryPath();
        debugPrint('[FolderImport] raw path from picker: $rawPath');
        if (rawPath == null || rawPath.isEmpty) return [];

        // Android's OPEN_DOCUMENT_TREE can return a content:// URI instead of
        // a real file path. Try to resolve it to an absolute path.
        final dirPath = _resolveAndroidUri(rawPath);
        debugPrint('[FolderImport] resolved path: $dirPath');

        // Detect cloud-provider "virtual" paths that look like real paths but
        // aren't on the local filesystem.
        // file_picker encodes Google Drive SAF URIs as:
        //   /storage/emulated/0/acc=1;doc=encoded=...
        // These are NOT real directories — dart:io cannot list them.
        final isCloudPath = rawPath.contains('acc=') ||
            rawPath.contains('doc=encoded=') ||
            rawPath.contains('com.google') ||
            rawPath.contains('com.dropbox') ||
            (!rawPath.startsWith('/storage') &&
                !rawPath.startsWith('/sdcard') &&
                rawPath.startsWith('/'));
        final dirExists = !isCloudPath && Directory(dirPath).existsSync();

        if (!dirExists) {
          debugPrint(
              '[FolderImport] path is not a local directory (cloud provider?)');
          if (context.mounted) {
            _showCloudFolderError(context, rawPath);
          }
          return [];
        }

        // List image files in the chosen directory.
        List<File> imageFiles = [];
        try {
          imageFiles = Directory(dirPath)
              .listSync(recursive: false)
              .whereType<File>()
              .where(
                  (f) => _imageExts.contains(p.extension(f.path).toLowerCase()))
              .toList()
            ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
          debugPrint('[FolderImport] found ${imageFiles.length} images');
        } catch (e, st) {
          debugPrint('[FolderImport] ERROR listing directory: $e\n$st');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not read folder: $e'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return [];
        }

        if (imageFiles.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No images found in:\n$dirPath'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return [];
        }

        if (!context.mounted) return [];

        // Show selection screen (starts with all ticked).
        final selected = await Navigator.push<List<File>>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => LocalFolderPickerScreen(
              files: imageFiles,
              dirPath: dirPath,
            ),
          ),
        );
        if (selected == null || selected.isEmpty) return [];
        return await Future.wait(selected.map((f) => f.readAsBytes()));

      // ── Google Drive folder ──────────────────────────────────────────────
      case PhotoPickSource.driveFolder:
        if (context == null || !context.mounted) return [];
        final results = await Navigator.push<List<Uint8List>>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const DriveFolderPickerScreen(),
          ),
        );
        return results ?? [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              _Tile(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                subtitle: 'Take a new photo',
                color: accentColor,
                onTap: () => Navigator.pop(context, PhotoPickSource.camera),
              ),
              _Tile(
                icon: Icons.photo_library_outlined,
                title: 'Photo Library',
                subtitle: 'Select one or more — includes iCloud, Google Photos',
                color: accentColor,
                onTap: () => Navigator.pop(context, PhotoPickSource.gallery),
              ),
              _Tile(
                icon: Icons.folder_open_outlined,
                title: 'Files / Cloud Drive',
                subtitle:
                    'Select individual files — Downloads, email attachments, cloud drives',
                color: accentColor,
                onTap: () => Navigator.pop(context, PhotoPickSource.files),
              ),
              _Tile(
                icon: Icons.drive_folder_upload_outlined,
                title: 'Import from Folder',
                subtitle: 'Pick a folder and select all images at once',
                color: accentColor,
                onTap: () =>
                    Navigator.pop(context, PhotoPickSource.localFolder),
              ),
              _Tile(
                icon: Icons.add_to_drive_outlined,
                title: 'Google Drive',
                subtitle: 'Browse a Drive folder and select images',
                color: accentColor,
                onTap: () =>
                    Navigator.pop(context, PhotoPickSource.driveFolder),
              ),
            ],
          ),
        ));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      onTap: onTap,
    );
  }
}
