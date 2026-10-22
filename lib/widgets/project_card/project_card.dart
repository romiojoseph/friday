import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_icon_button.dart';
import '../common/app_text_field.dart';
import '../common/spinner.dart';
import 'project_paths_view.dart';
import 'project_status_badge.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final int index;
  final String? busyAction;
  final Future<bool> Function(int index, String note) onBackup;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onPreview;
  final VoidCallback onOpenSource;
  final VoidCallback onOpenDestination;
  final Function(String msg, String type) showToast;

  const ProjectCard({
    super.key,
    required this.project,
    required this.index,
    this.busyAction,
    required this.onBackup,
    required this.onHistory,
    required this.onEdit,
    required this.onRemove,
    required this.onPreview,
    required this.onOpenSource,
    required this.onOpenDestination,
    required this.showToast,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard>
    with SingleTickerProviderStateMixin {
  final TextEditingController _noteController = TextEditingController();
  bool _isHovered = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBackingUp = widget.busyAction == 'backup';
    final isCleaning = widget.busyAction == 'cleanup';
    final isBusy = isBackingUp || isCleaning;

    final lastBackup = widget.project.lastBackup.isNotEmpty
        ? widget.project.lastBackup
        : 'Never';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: ShapeDecoration(
          color: AppColors.neutral0,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: _isHovered ? AppColors.neutral4 : AppColors.neutral3,
              width: 2,
            ),
          ),
          shadows: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isBackingUp)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return FractionalTranslation(
                      translation: Offset(_glowController.value * 2 - 1, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary450.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Project Name & Menu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.project.name,
                              style: AppTypography.subtitle.copyWith(
                                color: AppColors.neutral10.withValues(
                                  alpha: .85,
                                ),
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xxs,
                              children: [
                                Text(
                                  'v${widget.project.version}',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.neutral8,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: AppColors.neutral8.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Last: $lastBackup',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.neutral8,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: AppColors.neutral8.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                ProjectStatusBadge(
                                  status: widget.project.status,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconButton(
                            icon: const PhosphorIcon(
                              PhosphorIconsDuotone.gearSix,
                              size: 18,
                            ),
                            hoverIcon: const PhosphorIcon(
                              PhosphorIconsFill.gearSix,
                              size: 18,
                            ),
                            size: 36,
                            tooltip: 'Edit Config',
                            onClick: isBusy ? null : widget.onEdit,
                            disabled: isBusy,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          AppIconButton(
                            icon: const PhosphorIcon(
                              PhosphorIconsDuotone.trash,
                              color: AppColors.dangerBase,
                              size: 18,
                            ),
                            hoverIcon: const PhosphorIcon(
                              PhosphorIconsFill.trash,
                              color: AppColors.dangerBase,
                              size: 18,
                            ),
                            size: 36,
                            tooltip: 'Remove',
                            onClick: isBusy ? null : widget.onRemove,
                            disabled: isBusy,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Paths Grid
                  ProjectPathsView(
                    project: widget.project,
                    onOpenSource: widget.onOpenSource,
                    onOpenDestination: widget.onOpenDestination,
                    showToast: widget.showToast,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Exclusions Row
                  Row(
                    children: [
                      Text(
                        'Excluding: ',
                        style: AppTypography.body.copyWith(
                          color: AppColors.neutral8,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: widget.project.exclusionRules.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: AppSpacing.xxxs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral3,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.project.exclusionRules,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.neutral10,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : Text(
                                'No exclusion rules',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.neutral7,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Note Box
                  AppTextField(
                    controller: _noteController,
                    placeholder:
                        'Optional backup message... e.g. Before refactor / includes config change etc.',
                    maxLines: 2,
                  ),

                  // Active Writes Warning
                  if (widget.project.activeWrites) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusNewBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.statusNewBorder,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsFill.warning,
                            color: AppColors.statusNewText,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.project.activeWritesReason.isNotEmpty
                                  ? '${widget.project.activeWritesReason}. Make sure to close the file before backing up.'
                                  : 'Active writes detected (temp files or SQLite locks). Recommended to close the local app before backing up.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.statusNewText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: ButtonVariant.primary,
                          onClick: isBusy
                              ? null
                              : () async {
                                  final success = await widget.onBackup(
                                    widget.index,
                                    _noteController.text,
                                  );
                                  if (success && mounted) {
                                    _noteController.clear();
                                  }
                                },
                          disabled: isBusy,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          icon: isBackingUp
                              ? const Spinner(size: 16)
                              : const PhosphorIcon(
                                  PhosphorIconsDuotone.boxArrowDown,
                                  size: 18,
                                ),
                          hoverIcon: isBackingUp
                              ? null
                              : const PhosphorIcon(
                                  PhosphorIconsFill.boxArrowDown,
                                  size: 18,
                                ),
                          text: isBackingUp ? 'Backing Up...' : 'Backup Now',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          variant: ButtonVariant.secondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          icon: const PhosphorIcon(
                            PhosphorIconsDuotone.clockCounterClockwise,
                            size: 18,
                          ),
                          hoverIcon: const PhosphorIcon(
                            PhosphorIconsFill.clockCounterClockwise,
                            size: 18,
                          ),
                          text: 'History',
                          onClick: isBusy ? null : widget.onHistory,
                          disabled: isBusy,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppIconButton(
                        icon: const PhosphorIcon(
                          PhosphorIconsDuotone.folderOpen,
                          size: 20,
                        ),
                        hoverIcon: const PhosphorIcon(
                          PhosphorIconsFill.folderOpen,
                          size: 20,
                        ),
                        tooltip: 'Preview current files',
                        onClick: isBusy ? null : widget.onPreview,
                        disabled: isBusy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
