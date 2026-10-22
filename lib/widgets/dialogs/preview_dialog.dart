import 'package:flutter/material.dart';
import '../../models/file_diff_entry.dart';
import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_dialog.dart';
import '../common/file_diff_list.dart';
import '../common/spinner.dart';

class PreviewDialog extends StatelessWidget {
  final Project project;
  final List<FileDiffEntry> files;
  final bool loading;

  const PreviewDialog({
    super.key,
    required this.project,
    required this.files,
    this.loading = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Project project,
    required List<FileDiffEntry> files,
    bool loading = false,
  }) {
    return AppDialog.show(
      context: context,
      builder: (context) =>
          PreviewDialog(project: project, files: files, loading: loading),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      width: 700,
      height: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(
            title: 'Backup Preview',
            subtitle: Row(
              children: [
                Text(
                  project.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral11,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ' · Current state before backup',
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral8,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Spinner(size: 28),
                        SizedBox(height: AppSpacing.md),
                        Text('Loading preview...'),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.neutral1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neutral3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current backup state',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral7,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (files.isNotEmpty)
                              FileDiffCounters.fromFiles(files),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Expanded(
                          child: FileDiffList(
                            files: files,
                            emptyMessage: 'No files found for this source.',
                            showContainer: false,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
