import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'models/project.dart';
import 'providers/backup_provider.dart';
import 'services/backup_service.dart';
import 'services/explorer_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_typography.dart';
import 'widgets/common/app_button.dart';
import 'widgets/common/toast_overlay.dart';
import 'widgets/dialogs/confirm_dialog.dart';
import 'widgets/dialogs/global_settings_dialog.dart';
import 'widgets/dialogs/history_dialog.dart';
import 'widgets/dialogs/preview_dialog.dart';
import 'widgets/dialogs/project_settings_dialog.dart';
import 'widgets/header/app_header.dart';
import 'widgets/project_card/project_card.dart';

class HomeScreen extends StatefulWidget {
  final BackupProvider provider;

  const HomeScreen({super.key, required this.provider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ToastData> _toasts = [];

  @override
  void initState() {
    super.initState();
    widget.provider.onToast = _showToast;
  }

  void _showToast(String text, String type) {
    if (!mounted) return;
    setState(() {
      _toasts.add(
        ToastData(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: text,
          type: type,
        ),
      );
    });
  }

  void _dismissToast(String id) {
    if (!mounted) return;
    setState(() {
      _toasts.removeWhere((t) => t.id == id);
    });
  }

  Future<void> _onAddProject() async {
    await ProjectSettingsDialog.show(
      context,
      settings: widget.provider.settings,
      onSave: (proj) async {
        final ok = await widget.provider.addProject(proj);
        if (ok) {
          _showToast('Project added successfully!', 'success');
        } else {
          _showToast('Failed to add project.', 'error');
        }
      },
    );
  }

  Future<void> _onEditProject(int index) async {
    final project = widget.provider.projects[index];
    await ProjectSettingsDialog.show(
      context,
      project: project,
      settings: widget.provider.settings,
      onSave: (updated) async {
        final ok = await widget.provider.editProject(index, updated);
        if (ok) {
          _showToast('Project updated successfully!', 'success');
        } else {
          _showToast('Failed to update project.', 'error');
        }
      },
    );
  }

  Future<void> _onRemoveProject(int index) async {
    final project = widget.provider.projects[index];
    final ok = await ConfirmDialog.show(
      context,
      title: 'Remove project?',
      message: 'This removes the project configuration from Friday.',
      details: project.name,
      confirmText: 'Remove',
      cancelText: 'Cancel',
      variant: ButtonVariant.danger,
    );
    if (!ok) return;

    final res = await widget.provider.removeProject(index);
    if (res) {
      _showToast('Project removed successfully.', 'success');
    } else {
      _showToast('Failed to remove project.', 'error');
    }
  }

  Future<bool> _onBackup(int index, String note) async {
    final res = await widget.provider.triggerBackup(index, note);
    if (res.success) {
      _showToast(res.message, 'success');
      return true;
    } else if (res.skipped) {
      _showToast(res.message, 'info');
      return false;
    } else {
      _showToast(res.message, 'error');
      return false;
    }
  }

  Future<void> _onHistory(int index) async {
    final project = widget.provider.projects[index];
    final rows = await widget.provider.fetchBackups(index);
    if (!mounted) return;

    await HistoryDialog.show(
      context,
      project: project,
      rows: rows,
      onDeleteMultiple: (filenames) async {
        final ok = await ConfirmDialog.show(
          context,
          title: 'Delete ${filenames.length} backup version(s)?',
          message:
              'This will permanently delete the selected backup zip files from Friday\'s storage.',
          details: filenames.join('\n'),
          confirmText: 'Delete Selected',
          cancelText: 'Cancel',
          variant: ButtonVariant.danger,
        );
        if (!ok) return false;

        final count = await widget.provider.deleteBackups(index, filenames);
        _showToast('$count backup version(s) deleted successfully.', 'success');
        return count > 0;
      },
      showToast: _showToast,
    );
  }

  Future<void> _onPreview(int index) async {
    final project = widget.provider.projects[index];
    final scan = await widget.provider.fetchPreview(index);

    if (!mounted) return;
    await PreviewDialog.show(context, project: project, files: scan.files);
  }

  Future<void> _onOpenGlobalSettings() async {
    await GlobalSettingsDialog.show(
      context,
      settings: widget.provider.settings,
      onSave: (settings) async {
        await widget.provider.saveSettings(settings);
        _showToast('Settings saved.', 'success');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.provider.projects;

    return Scaffold(
      backgroundColor: AppColors.neutral1,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHeader(
                onAddProject: _onAddProject,
                onOpenGlobalSettings: _onOpenGlobalSettings,
              ),
              Expanded(
                child: projects.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PhosphorIcon(
                                PhosphorIconsDuotone.folderDashed,
                                color: AppColors.neutral7,
                                size: 64,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                "Click '+ Add Project' to set up your first folder backup!",
                                style: AppTypography.heading6.copyWith(
                                  color: AppColors.neutral8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: LayoutBuilder(
                          builder: (context, gridConstraints) {
                            const spacing = AppSpacing.md;
                            const minCardWidth = 360.0;
                            int crossAxisCount =
                                (gridConstraints.maxWidth / minCardWidth)
                                    .floor();
                            if (crossAxisCount < 1) crossAxisCount = 1;
                            if (crossAxisCount > 3) crossAxisCount = 3;

                            final totalSpacing = spacing * (crossAxisCount - 1);
                            final itemWidth =
                                (gridConstraints.maxWidth - totalSpacing) /
                                crossAxisCount;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: List.generate(projects.length, (idx) {
                                return SizedBox(
                                  key: ValueKey('${projects[idx].source}_$idx'),
                                  width: itemWidth,
                                  child: ProjectCard(
                                    project: projects[idx],
                                    index: idx,
                                    busyAction: widget.provider.busy[idx],
                                    onBackup: _onBackup,
                                    onHistory: () => _onHistory(idx),
                                    onEdit: () => _onEditProject(idx),
                                    onRemove: () => _onRemoveProject(idx),
                                    onPreview: () => _onPreview(idx),
                                    onOpenSource: () async {
                                      final ok =
                                          await ExplorerService.openInExplorer(
                                            projects[idx].source,
                                          );
                                      if (!ok) {
                                        _showToast(
                                          'Source folder not found.',
                                          'error',
                                        );
                                      }
                                    },
                                    onOpenDestination: () async {
                                      final dst = widget.provider
                                          .resolveDestination(projects[idx]);
                                      final ok =
                                          await ExplorerService.openInExplorer(
                                            dst,
                                          );
                                      if (!ok) {
                                        _showToast(
                                          'Destination folder not found.',
                                          'error',
                                        );
                                      }
                                    },
                                    showToast: _showToast,
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          ToastOverlay(toasts: _toasts, onDismiss: _dismissToast),
        ],
      ),
    );
  }
}

extension BackupProviderHelper on BackupProvider {
  String resolveDestination(Project proj) {
    const bs = BackupService();
    return bs.resolveDestination(proj, settings);
  }
}
