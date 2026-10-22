import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/exclusions_config.dart';
import '../../models/project.dart';
import '../../models/settings.dart';
import '../../services/explorer_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../common/app_button.dart';
import '../common/app_checkbox.dart';
import '../common/app_dialog.dart';
import '../common/app_text_field.dart';
import '../settings/exclusion_patterns_manager.dart';

class ProjectSettingsDialog extends StatefulWidget {
  final Project? project;
  final Settings settings;
  final Function(Project project) onSave;

  const ProjectSettingsDialog({
    super.key,
    this.project,
    required this.settings,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    Project? project,
    required Settings settings,
    required Function(Project project) onSave,
  }) {
    return AppDialog.show(
      context: context,
      builder: (context) => ProjectSettingsDialog(
        project: project,
        settings: settings,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ProjectSettingsDialog> createState() => _ProjectSettingsDialogState();
}

class _ProjectSettingsDialogState extends State<ProjectSettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _sourceController;
  late TextEditingController _destinationController;
  late TextEditingController _exclusionRulesController;
  late bool _useGlobalDestination;
  late bool _useProjectSubfolder;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p?.name ?? '');
    _sourceController = TextEditingController(text: p?.source ?? '');
    _destinationController = TextEditingController(text: p?.destination ?? '');
    _exclusionRulesController = TextEditingController(
      text: p != null ? p.exclusionRules : defaultExclusionRules,
    );
    _useGlobalDestination = p?.useGlobalDestination ?? false;
    _useProjectSubfolder =
        p?.useProjectSubfolder ?? widget.settings.useProjectSubfolderDefault;

    _nameController.addListener(() => setState(() {}));
    _destinationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sourceController.dispose();
    _destinationController.dispose();
    _exclusionRulesController.dispose();
    super.dispose();
  }

  String get _resolvedPreview {
    String base = '';
    if (_useGlobalDestination) {
      base = widget.settings.globalBackupDir.trim();
      if (base.isEmpty) return '(Global backup folder not configured)';
    } else {
      base = _destinationController.text.trim();
      if (base.isEmpty) return '';
    }

    if (_useProjectSubfolder) {
      final subName = Formatters.sanitizeFilename(_nameController.text.trim());
      return p.join(base, subName);
    }
    return base;
  }

  Future<void> _browseSourceFolder() async {
    final path = await ExplorerService.pickDirectory(
      dialogTitle: 'Select Source Folder',
    );
    if (path != null && path.trim().isNotEmpty) {
      setState(() {
        _sourceController.text = path.trim();
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = p.basename(path.trim());
        }
      });
    }
  }

  Future<void> _browseSourceFile() async {
    final path = await ExplorerService.pickFile(
      dialogTitle: 'Select Source File',
    );
    if (path != null && path.trim().isNotEmpty) {
      setState(() {
        _sourceController.text = path.trim();
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = p.basenameWithoutExtension(path.trim());
        }
      });
    }
  }

  Future<void> _browseDestination() async {
    final path = await ExplorerService.pickDirectory(
      dialogTitle: 'Select Destination Folder',
    );
    if (path != null && path.trim().isNotEmpty) {
      setState(() {
        _destinationController.text = path.trim();
      });
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    final source = _sourceController.text.trim();
    final destination = _destinationController.text.trim();

    if (name.isEmpty ||
        source.isEmpty ||
        (!_useGlobalDestination && destination.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required.'),
          backgroundColor: AppColors.dangerBase,
        ),
      );
      return;
    }

    final updated = (widget.project ?? const Project(name: '', source: ''))
        .copyWith(
          name: name,
          source: source,
          destination: _useGlobalDestination ? '' : destination,
          exclusionRules: _exclusionRulesController.text.trim(),
          useGlobalDestination: _useGlobalDestination,
          useProjectSubfolder: _useProjectSubfolder,
        );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;

    return AppDialog(
      width: 660,
      constraints: const BoxConstraints(maxHeight: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(title: isEdit ? 'Edit Project' : 'Add Project'),

          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Project Name
                  Text(
                    'Project Name',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral9,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: _nameController,
                    placeholder: 'e.g. My Website Development',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Source
                  Text(
                    'Source File or Folder',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral9,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _sourceController,
                          placeholder: r'C:\path\to\source',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        variant: ButtonVariant.secondary,
                        icon: const PhosphorIcon(PhosphorIconsDuotone.folder),
                        hoverIcon: const PhosphorIcon(PhosphorIconsFill.folder),
                        text: 'Folder',
                        onClick: _browseSourceFolder,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppButton(
                        variant: ButtonVariant.secondary,
                        icon: const PhosphorIcon(PhosphorIconsDuotone.file),
                        hoverIcon: const PhosphorIcon(PhosphorIconsFill.file),
                        text: 'File',
                        onClick: _browseSourceFile,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Destination
                  Text(
                    'Destination Folder',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral9,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _destinationController,
                          placeholder: _useGlobalDestination
                              ? 'Global Backup Path'
                              : r'D:\backups',
                          disabled: _useGlobalDestination,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        variant: ButtonVariant.secondary,
                        icon: const PhosphorIcon(PhosphorIconsDuotone.folder),
                        hoverIcon: const PhosphorIcon(PhosphorIconsFill.folder),
                        text: 'Folder',
                        onClick: _useGlobalDestination
                            ? null
                            : _browseDestination,
                        disabled: _useGlobalDestination,
                      ),
                    ],
                  ),
                  if (_resolvedPreview.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Live Preview: $_resolvedPreview',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral8,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Checkboxes
                  AppCheckbox(
                    value: _useGlobalDestination,
                    label: 'Use global backup folder (if configured)',
                    onChanged: (val) =>
                        setState(() => _useGlobalDestination = val),
                  ),
                  AppCheckbox(
                    value: _useProjectSubfolder,
                    label: 'Create subfolder with project name',
                    onChanged: (val) =>
                        setState(() => _useProjectSubfolder = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Exclusion Rules & Filters Manager
                  ExclusionPatternsManager(
                    initialPatterns: ExclusionsConfig.parseRulesString(
                      _exclusionRulesController.text,
                    ),
                    sourcePath: _sourceController.text.trim().isNotEmpty
                        ? _sourceController.text.trim()
                        : null,
                    onChanged: (patterns) {
                      _exclusionRulesController.text = patterns.join(', ');
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Footer
          AppDialogFooter(
            children: [
              AppButton(
                variant: ButtonVariant.secondary,
                text: 'Cancel',
                onClick: () => Navigator.of(context).pop(),
              ),
              AppButton(
                variant: ButtonVariant.primary,
                icon: const PhosphorIcon(PhosphorIconsDuotone.checkCircle),
                hoverIcon: const PhosphorIcon(PhosphorIconsFill.checkCircle),
                text: isEdit ? 'Update Project' : 'Save Project',
                onClick: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
