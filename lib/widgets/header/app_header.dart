import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';

class WindowCaptionButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onTap;
  final bool isClose;

  const WindowCaptionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color iconColor = AppColors.neutral9;

    if (_isHovered) {
      if (widget.isClose) {
        bg = AppColors.dangerBase;
        iconColor = AppColors.neutral12;
      } else {
        bg = AppColors.neutral3;
        iconColor = AppColors.neutral12;
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 38,
          color: bg,
          alignment: Alignment.center,
          child: IconTheme(
            data: IconThemeData(color: iconColor, size: 14),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}

class AppHeader extends StatefulWidget {
  final VoidCallback onAddProject;
  final VoidCallback onOpenGlobalSettings;

  const AppHeader({
    super.key,
    required this.onAddProject,
    required this.onOpenGlobalSettings,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final max = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = max);
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.neutral1,
        border: Border(bottom: BorderSide(color: AppColors.neutral3, width: 1)),
      ),
      child: Row(
        children: [
          DragToMoveArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: AppSpacing.md),
                Image.asset(
                  'assets/app_icon.png',
                  width: 22,
                  height: 22,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Friday Backup Manager',
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                variant: ButtonVariant.secondary,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                icon: const PhosphorIcon(
                  PhosphorIconsDuotone.gearSix,
                  size: 18,
                ),
                hoverIcon: const PhosphorIcon(
                  PhosphorIconsFill.gearSix,
                  size: 18,
                ),
                text: 'Settings',
                onClick: widget.onOpenGlobalSettings,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                variant: ButtonVariant.primary,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                icon: const PhosphorIcon(
                  PhosphorIconsDuotone.folderSimplePlus,
                  size: 18,
                ),
                hoverIcon: const PhosphorIcon(
                  PhosphorIconsFill.folderSimplePlus,
                  size: 18,
                ),
                text: 'Add Project',
                onClick: widget.onAddProject,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WindowCaptionButton(
                icon: Icon(PhosphorIconsBold.minus),
                onTap: () => windowManager.minimize(),
              ),
              WindowCaptionButton(
                icon: Icon(
                  _isMaximized
                      ? PhosphorIconsBold.copy
                      : PhosphorIconsBold.square,
                ),
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
              WindowCaptionButton(
                isClose: true,
                icon: Icon(PhosphorIconsBold.x),
                onTap: () => windowManager.close(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
