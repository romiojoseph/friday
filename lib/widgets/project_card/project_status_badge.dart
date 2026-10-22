import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_constants.dart';
import '../common/status_badge.dart';

class ProjectStatusBadge extends StatelessWidget {
  final String status; // "clean", "modified", "new"

  const ProjectStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case ProjectStatus.modified:
        fg = AppColors.statusModifiedText;
        icon = PhosphorIconsFill.gitDiff;
        label = 'Unsaved changes';
        break;
      case ProjectStatus.clean:
        fg = AppColors.statusCleanText;
        icon = PhosphorIconsFill.checkCircle;
        label = 'Up-to-date';
        break;
      default:
        fg = AppColors.statusNewText;
        icon = PhosphorIconsFill.warningCircle;
        label = 'No backups';
        break;
    }

    return StatusBadge(
      label: label,
      icon: icon,
      color: fg,
    );
  }
}
