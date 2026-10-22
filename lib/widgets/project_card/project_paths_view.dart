import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';

class ProjectPathsView extends StatelessWidget {
  final Project project;
  final VoidCallback onOpenSource;
  final VoidCallback onOpenDestination;
  final Function(String msg, String type) showToast;

  const ProjectPathsView({
    super.key,
    required this.project,
    required this.onOpenSource,
    required this.onOpenDestination,
    required this.showToast,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDst = project.destinationEffective.isNotEmpty
        ? project.destinationEffective
        : project.destination;

    final lastZipHash = project.backupHashes[project.lastZipName] ?? '';

    final sourceHash = project.currentHash.isNotEmpty
        ? project.currentHash
        : project.contentHash;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PathBlock(
            icon: PhosphorIconsDuotone.database,
            hoverIcon: PhosphorIconsFill.database,
            label: 'Source',
            path: project.source,
            sizeText: Formatters.formatBytes(project.srcSize),
            countText: '(${project.srcCount} files)',
            hashText: sourceHash,
            onOpen: onOpenSource,
            onCopyHash: sourceHash.isNotEmpty
                ? () async {
                    await Clipboard.setData(ClipboardData(text: sourceHash));
                    showToast('Copied content hash to clipboard!', 'success');
                  }
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _PathBlock(
            icon: PhosphorIconsDuotone.cloud,
            hoverIcon: PhosphorIconsFill.cloud,
            label: 'Destination',
            path: effectiveDst,
            sizeText: Formatters.formatBytes(project.dstSize),
            countText: '(${project.dstCount} zips)',
            hashText: lastZipHash,
            onOpen: onOpenDestination,
            onCopyHash: lastZipHash.isNotEmpty
                ? () async {
                    await Clipboard.setData(ClipboardData(text: lastZipHash));
                    showToast('Copied ZIP hash to clipboard!', 'success');
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _PathBlock extends StatefulWidget {
  final Object icon;
  final Object hoverIcon;
  final String label;
  final String path;
  final String sizeText;
  final String countText;
  final String hashText;
  final VoidCallback onOpen;
  final VoidCallback? onCopyHash;

  const _PathBlock({
    required this.icon,
    required this.hoverIcon,
    required this.label,
    required this.path,
    required this.sizeText,
    required this.countText,
    required this.hashText,
    required this.onOpen,
    this.onCopyHash,
  });

  @override
  State<_PathBlock> createState() => _PathBlockState();
}

class _PathBlockState extends State<_PathBlock> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.neutral4 : AppColors.neutral3,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PhosphorIcon(
                    _isHovered ? widget.hoverIcon : widget.icon,
                    color: _isHovered ? AppColors.neutral10 : AppColors.neutral8,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    widget.label.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Tooltip(
                message: widget.path.isNotEmpty ? widget.path : 'None',
                waitDuration: const Duration(milliseconds: 300),
                child: Text(
                  widget.path.isNotEmpty ? widget.path : 'None',
                  style: AppTypography.body.copyWith(
                    color: _isHovered ? AppColors.neutral12 : AppColors.neutral8,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    widget.sizeText,
                    style: AppTypography.heading6.copyWith(
                      color: AppColors.neutral9,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    widget.countText,
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral8,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (widget.hashText.isNotEmpty)
                GestureDetector(
                  onTap: widget.onCopyHash,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      widget.hashText,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral8,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                Text(
                  'No hash available',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral7,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
