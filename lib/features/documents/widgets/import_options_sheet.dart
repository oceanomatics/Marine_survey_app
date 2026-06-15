// lib/features/documents/widgets/import_options_sheet.dart

import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class ImportOptionsSheet extends StatelessWidget {
  const ImportOptionsSheet({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onFile,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Import Document',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Claude will read the document and extract\nvessel data automatically.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _Option(
            icon: Icons.camera_alt_outlined,
            color: AppColors.midBlue,
            bgColor: AppColors.lightBlue,
            title: 'Take a photo',
            subtitle: 'Photograph a certificate or document on the vessel',
            onTap: onCamera,
          ),
          const SizedBox(height: 10),
          _Option(
            icon: Icons.photo_library_outlined,
            color: AppColors.teal,
            bgColor: AppColors.lightTeal,
            title: 'Choose from gallery',
            subtitle: 'Import a photo already on your device',
            onTap: onGallery,
          ),
          const SizedBox(height: 10),
          _Option(
            icon: Icons.upload_file_outlined,
            color: AppColors.amber,
            bgColor: AppColors.lightAmber,
            title: 'Upload a file',
            subtitle: 'Import a PDF, JPG or PNG from your device',
            onTap: onFile,
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7))),
              ],
            )),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}
