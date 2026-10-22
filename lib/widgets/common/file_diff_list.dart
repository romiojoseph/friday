import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/file_diff_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';

/// Renders a single file entry in a diff or snapshot list.
class FileDiffTile extends StatelessWidget {
  final FileDiffEntry file;

  const FileDiffTile({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.diffUnchanged;
    Object statusIcon = PhosphorIconsRegular.file;
    TextDecoration decoration = TextDecoration.none;

    switch (file.status) {
      case 'added':
        color = AppColors.diffAdded;
        statusIcon = PhosphorIconsDuotone.plusCircle;
        break;
      case 'modified':
        color = AppColors.diffModified;
        statusIcon = PhosphorIconsDuotone.pencilSimple;
        break;
      case 'deleted':
        color = AppColors.diffDeleted;
        statusIcon = PhosphorIconsDuotone.minusCircle;
        decoration = TextDecoration.lineThrough;
        break;
      case 'skipped':
        color = AppColors.diffSkipped;
        statusIcon = PhosphorIconsDuotone.prohibit;
        break;
    }

    final sizeText = file.status == 'skipped'
        ? 'Skipped'
        : file.size != null
        ? Formatters.formatBytes(file.size!)
        : file.status;

    return SizedBox(
      height: 28.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 3,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            PhosphorIcon(statusIcon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                file.path,
                style: AppTypography.caption.copyWith(
                  color: color,
                  decoration: decoration,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              sizeText,
              style: AppTypography.caption.copyWith(
                color: color,
                decoration: decoration,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact badge row summarizing file diff counts (added, modified, deleted, skipped).
class FileDiffCounters extends StatelessWidget {
  final int added;
  final int modified;
  final int deleted;
  final int skipped;

  const FileDiffCounters({
    super.key,
    required this.added,
    required this.modified,
    required this.deleted,
    required this.skipped,
  });

  factory FileDiffCounters.fromFiles(List<FileDiffEntry> files) {
    int added = 0;
    int modified = 0;
    int deleted = 0;
    int skipped = 0;

    for (final f in files) {
      switch (f.status) {
        case 'added':
          added++;
          break;
        case 'modified':
          modified++;
          break;
        case 'deleted':
          deleted++;
          break;
        case 'skipped':
          skipped++;
          break;
      }
    }

    return FileDiffCounters(
      added: added,
      modified: modified,
      deleted: deleted,
      skipped: skipped,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (added > 0) ...[
          _buildItem(PhosphorIconsDuotone.filePlus, '$added', AppColors.diffAdded),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (modified > 0) ...[
          _buildItem(PhosphorIconsDuotone.pencilSimple, '$modified', AppColors.diffModified),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (deleted > 0) ...[
          _buildItem(PhosphorIconsDuotone.trash, '$deleted', AppColors.diffDeleted),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (skipped > 0) ...[
          _buildItem(PhosphorIconsDuotone.prohibit, '$skipped skipped', AppColors.diffSkipped),
        ],
      ],
    );
  }

  Widget _buildItem(Object icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Centralized virtualized list for displaying [FileDiffEntry] collections.
class FileDiffList extends StatelessWidget {
  final List<FileDiffEntry> files;
  final String emptyMessage;
  final bool showContainer;
  final EdgeInsetsGeometry padding;

  const FileDiffList({
    super.key,
    required this.files,
    this.emptyMessage = 'No files tracked.',
    this.showContainer = true,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: AppTypography.body.copyWith(
            color: AppColors.neutral7,
            fontSize: 13,
          ),
        ),
      );
    }

    final listView = ListView.builder(
      itemCount: files.length,
      itemExtent: 28.0,
      padding: EdgeInsets.zero,
      itemBuilder: (context, idx) => FileDiffTile(file: files[idx]),
    );

    if (!showContainer) {
      return listView;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral3),
      ),
      padding: padding,
      child: listView,
    );
  }
}
