import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_icon_button.dart';

/// Reusable modal container that enforces consistent sizing, continuous borders,
/// shadows, and background styling across application dialogs.
class AppDialog extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const AppDialog({
    super.key,
    this.width,
    this.height,
    this.constraints,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    required this.child,
  });

  /// Displays a modal dialog with standard theme styling and barrier color.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        width: width,
        height: height,
        constraints: constraints,
        decoration: ShapeDecoration(
          color: AppColors.neutral2,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: AppColors.neutral3, width: 2),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Standardized header for [AppDialog] with title, optional subtitle, and close button.
class AppDialogHeader extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;
  final bool showCloseButton;

  const AppDialogHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.showCloseButton = true,
  }) : assert(title != null || titleWidget != null);

  @override
  Widget build(BuildContext context) {
    final closeBtn =
        trailing ??
        (showCloseButton
            ? AppIconButton.ghost(
                icon: const PhosphorIcon(PhosphorIconsBold.x),
                onClick: onClose ?? () => Navigator.of(context).pop(),
              )
            : null);

    final titleContent =
        titleWidget ??
        Text(
          title!,
          style: AppTypography.heading6.copyWith(
            color: AppColors.neutral11,
            fontWeight: FontWeight.bold,
          ),
        );

    final titleRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleContent),
        ?closeBtn,
      ],
    );

    if (subtitle != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleRow,
          const SizedBox(height: AppSpacing.xs),
          subtitle!,
        ],
      );
    }

    return titleRow;
  }
}

/// Standardized footer for [AppDialog] with aligned action buttons
/// and consistent inter-button spacing.
class AppDialogFooter extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;

  const AppDialogFooter({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final spacedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        spacedChildren.add(const SizedBox(width: AppSpacing.sm));
      }
      spacedChildren.add(children[i]);
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: spacedChildren,
    );
  }
}
