// lib/features/documents/widgets/document_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/document_provider.dart';
import '../../../shared/theme/app_theme.dart';

class DocumentTile extends ConsumerWidget {
  const DocumentTile({
    super.key,
    required this.doc,
    required this.onDelete,
  });

  final DocumentModel doc;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // File type icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _iconBg(doc),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon(doc), color: _iconColor(doc), size: 20),
          ),
          const SizedBox(width: 12),

          // Title and metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  // Availability badge
                  _Badge(doc.availability.label, _availColor(doc.availability)),
                  const SizedBox(width: 6),
                  // AI extracted badge
                  if (doc.aiExtracted)
                    const _Badge('AI extracted', AppColors.purple),
                ]),
                if (doc.docDate != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(doc.docDate!),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textTertiary, size: 18),
            onSelected: (v) {
              if (v == 'delete') onDelete(doc.docId);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      color: AppColors.error, size: 16),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(color: AppColors.error, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  IconData _icon(DocumentModel doc) {
    if (doc.isPdf) return Icons.picture_as_pdf_outlined;
    if (doc.isImage) return Icons.image_outlined;
    if (doc.availability == DocAvailability.requested) {
      return Icons.hourglass_empty_outlined;
    }
    return Icons.description_outlined;
  }

  Color _iconBg(DocumentModel doc) {
    if (doc.isPdf) return AppColors.lightCoral;
    if (doc.isImage) return AppColors.lightBlue;
    if (doc.availability == DocAvailability.requested) {
      return AppColors.lightAmber;
    }
    return AppColors.lightAmber;
  }

  Color _iconColor(DocumentModel doc) {
    if (doc.isPdf) return AppColors.coral;
    if (doc.isImage) return AppColors.midBlue;
    if (doc.availability == DocAvailability.requested) return AppColors.amber;
    return AppColors.amber;
  }

  Color _availColor(DocAvailability av) => switch (av) {
    DocAvailability.enclosed     => AppColors.success,
    DocAvailability.requested    => AppColors.warning,
    DocAvailability.notAvailable => AppColors.error,
    DocAvailability.tbc          => AppColors.textSecondary,
  };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
